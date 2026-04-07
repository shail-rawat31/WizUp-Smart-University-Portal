const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SUPABASE_URL = "https://vqxhbfbpqwpdbmgtdcik.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE";
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function provision() {
    let log = "🚀 Starting Institutional Provisioning...\n";

    const users = [];
    const dept = "MCA";

    users.push({
        id: "hod-mca-9999",
        full_name: "Dr. HOD Supervisor",
        role: "hod",
        department: dept,
        employee_id: "HOD-MCA-001",
        email: "hod.mca@wizup.edu"
    });

    for(let i=1; i<=7; i++) {
        users.push({
            id: `faculty-mca-00${i}`,
            full_name: `Prof. Faculty Member ${i}`,
            role: "faculty",
            department: dept,
            employee_id: `FAC-MCA-00${i}`,
            email: `fac${i}.mca@wizup.edu`
        });
    }

    for(let i=1; i<=40; i++) {
        users.push({
            id: `student-mca-${i < 10 ? '0' + i : i}`,
            full_name: `Student Candidate ${i}`,
            role: "student",
            department: dept,
            roll_no: `MCA-2025-${i < 10 ? '0' + i : i}`,
            email: `student${i}.mca@wizup.edu`
        });
    }

    log += `📡 Broadcasting ${users.length} identities...\n`;

    const { error } = await db.from('profiles').upsert(users);

    if (error) {
        log += "❌ Error: " + error.message + "\n";
    } else {
        log += "✅ Synchronization Complete.\n";
        log += `- HOD: 1\n- Faculty: 7\n- Students: 40\n`;
    }

    fs.writeFileSync('provision.log', log);
    console.log(log);
}

provision();
