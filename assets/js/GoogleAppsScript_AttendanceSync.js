// ============================================================================
// WIZUP — Google Sheets → Supabase Attendance Sync
// ============================================================================
// HOW TO USE:
//  1. Open your Google Sheet → Extensions → Apps Script
//  2. Paste this entire file → Save (Ctrl+S)
//  3. Fill in SUPABASE_URL and SUPABASE_SERVICE_KEY below
//  4. Run setupTrigger() ONCE from the Run menu to install the auto-sync trigger
//  5. Format your Sheet columns as:
//       A: Date (e.g. 2026-03-23)  B: Roll No  C: Subject Code  D: Status (present/absent/leave)
//       Row 1 = Header, data starts Row 2
// ============================================================================

// ── CONFIG ──────────────────────────────────────────────────────────────────
const SUPABASE_URL = "https://vqxhbfbpqwpdbmgtdcik.supabase.co";
const SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTgxNjUxMywiZXhwIjoyMDg3MzkyNTEzfQ.XjEUvo4GRNjmlO0rgO4K5ydS9SnZtgDbI563F_4SiOw"; // ← Paste from Supabase → Settings → API
const SHEET_NAME = "Attendance";   // Tab name in your Google Sheet
const HEADER_ROWS = 1;              // Rows to skip (header)

// Column indices (0-based)
const COL_DATE = 0;  // Column A
const COL_ROLL = 1;  // Column B
const COL_SUBJECT = 2;  // Column C
const COL_STATUS = 3;  // Column D
const COL_SYNCED = 4;  // Column E — script writes "✓ Synced" / "✗ Error: ..."
// ────────────────────────────────────────────────────────────────────────────

/**
 * Called automatically on every sheet edit.
 * Only triggers when editing inside the data range.
 */
function onSheetEdit(e) {
    try {
        const sheet = e.source.getSheetByName(SHEET_NAME);
        if (!sheet) return;

        const range = e.range;
        const row = range.getRow();
        if (row <= HEADER_ROWS) return; // skip header

        const rowData = sheet.getRange(row, 1, 1, 5).getValues()[0];
        syncRow(sheet, row, rowData);
    } catch (err) {
        console.error("onSheetEdit error:", err);
    }
}

/**
 * Manual full sync — syncs ALL rows that haven't been synced yet.
 * Run this from the Apps Script editor to do a bulk import.
 */
function syncAllPending() {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
    if (!sheet) { Logger.log("Sheet '" + SHEET_NAME + "' not found"); return; }

    const lastRow = sheet.getLastRow();
    if (lastRow <= HEADER_ROWS) { Logger.log("No data rows found"); return; }

    const data = sheet.getRange(HEADER_ROWS + 1, 1, lastRow - HEADER_ROWS, 5).getValues();

    let success = 0, errors = 0;
    data.forEach((row, i) => {
        const sheetRow = HEADER_ROWS + 1 + i;
        const synced = String(row[COL_SYNCED]).trim();
        if (synced.startsWith("✓")) return; // already synced, skip
        const result = syncRow(sheet, sheetRow, row);
        if (result) success++; else errors++;
    });

    Logger.log(`Sync complete: ${success} synced, ${errors} errors`);
    SpreadsheetApp.getUi().alert(`Sync complete!\n✓ ${success} records synced\n✗ ${errors} errors`);
}

/**
 * Syncs a single row to Supabase.
 * @returns {boolean} true on success
 */
function syncRow(sheet, rowNum, rowData) {
    const rawDate = rowData[COL_DATE];
    const roll = String(rowData[COL_ROLL]).trim();
    const subCode = String(rowData[COL_SUBJECT]).trim();
    const status = String(rowData[COL_STATUS]).trim().toLowerCase();

    // Validate
    if (!rawDate || !roll || !subCode || !status) {
        sheet.getRange(rowNum, COL_SYNCED + 1).setValue("⚠ Skip: empty fields");
        return false;
    }

    if (!["present", "absent", "leave"].includes(status)) {
        sheet.getRange(rowNum, COL_SYNCED + 1).setValue("✗ Error: status must be present/absent/leave");
        return false;
    }

    // Format date as YYYY-MM-DD
    const dateObj = new Date(rawDate);
    const dateStr = Utilities.formatDate(dateObj, Session.getScriptTimeZone(), "yyyy-MM-dd");

    // Call Supabase RPC
    const payload = {
        p_roll: roll,
        p_subject_code: subCode,
        p_date: dateStr,
        p_status: status
    };

    try {
        const response = UrlFetchApp.fetch(
            SUPABASE_URL + "/rest/v1/rpc/upsert_attendance_from_sheet",
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "apikey": SUPABASE_SERVICE_KEY,
                    "Authorization": "Bearer " + SUPABASE_SERVICE_KEY,
                    "Prefer": "return=representation"
                },
                payload: JSON.stringify(payload),
                muteHttpExceptions: true
            }
        );

        const code = response.getResponseCode();
        const body = response.getContentText();
        const json = JSON.parse(body);

        if (code === 200 && json && json.success) {
            const ts = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "dd/MM HH:mm");
            sheet.getRange(rowNum, COL_SYNCED + 1).setValue(`✓ Synced ${ts}`);
            return true;
        } else {
            const msg = (json && json.error) ? json.error : `HTTP ${code}`;
            sheet.getRange(rowNum, COL_SYNCED + 1).setValue(`✗ Error: ${msg}`);
            Logger.log(`Row ${rowNum} failed: ${msg}`);
            return false;
        }
    } catch (err) {
        sheet.getRange(rowNum, COL_SYNCED + 1).setValue(`✗ Network: ${err.message}`);
        Logger.log(`Row ${rowNum} network error: ${err}`);
        return false;
    }
}

/**
 * Run ONCE to install the onEdit trigger.
 * After running, every cell edit in the Sheet auto-syncs to Supabase.
 */
function setupTrigger() {
    // Remove existing triggers first to avoid duplicates
    const triggers = ScriptApp.getProjectTriggers();
    triggers.forEach(t => {
        if (t.getHandlerFunction() === "onSheetEdit") {
            ScriptApp.deleteTrigger(t);
        }
    });

    ScriptApp.newTrigger("onSheetEdit")
        .forSpreadsheet(SpreadsheetApp.getActiveSpreadsheet())
        .onEdit()
        .create();

    SpreadsheetApp.getUi().alert(
        "✓ Trigger installed!\n\nNow every time you edit a row in the '" + SHEET_NAME + "' sheet, " +
        "it will automatically sync to the WizUP Supabase database."
    );
}

/**
 * Adds a custom menu to the Google Sheet UI.
 */
function onOpen() {
    SpreadsheetApp.getUi()
        .createMenu("🎓 WizUP Sync")
        .addItem("Sync All Pending Rows", "syncAllPending")
        .addItem("Install Auto-Sync Trigger", "setupTrigger")
        .addToUi();
}
