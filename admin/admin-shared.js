// ============================================================
// ADMIN SHARED JS — admin-shared.js
// Supabase client, auth guard, sidebar, toast, helpers
// ============================================================

var SUPABASE_URL = "https://vqxhbfbpqwpdbmgtdcik.supabase.co";
var SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE";
var db = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

var adminProfile = null;

// ── Auth guard ──────────────────────────────────
async function requireAdmin() {
  var res = await db.auth.getSession();
  var session = res.data.session;
  if (!session) { window.location.href = "admin-signin.html"; return null; }
  var pRes = await db.from("profiles").select("*").eq("id", session.user.id).single();
  var profile = pRes.data;
  if (!profile || profile.role !== "admin") { window.location.href = "../index.html"; return null; }
  adminProfile = profile;
  document.body.style.display = "block";

  // Populate header user info
  var name = profile.full_name || "Admin";
  var el = document.getElementById("userAvatar");
  if (el) el.textContent = name[0].toUpperCase();
  var el2 = document.getElementById("userName");
  if (el2) el2.textContent = name.split(" ")[0];
  return profile;
}

// ── Sign out ────────────────────────────────────
function doSignOut() {
  db.auth.signOut().then(function() { window.location.href = "../index.html"; });
}

// ── Sidebar accordion ───────────────────────────
function initSidebar() {
  // Mark active link
  var path = window.location.pathname.split("/").pop();
  document.querySelectorAll(".sb-menu a").forEach(function(a) {
    if (a.getAttribute("href") === path) a.classList.add("active");
  });
  // Accordion
  document.querySelectorAll(".sb-hd").forEach(function(h) {
    h.addEventListener("click", function() {
      h.parentElement.classList.toggle("open");
    });
  });
}

// ── Toast ───────────────────────────────────────
function showToast(msg, type) {
  type = type || "success";
  var wrap = document.getElementById("toastWrap");
  if (!wrap) { wrap = document.createElement("div"); wrap.id = "toastWrap"; document.body.appendChild(wrap); }
  var map = { success: "t-success", error: "t-error", info: "t-info", warn: "t-warn" };
  var icons = { success: "✓", error: "✗", info: "ℹ", warn: "⚠" };
  var t = document.createElement("div");
  t.className = "t-item " + (map[type] || "t-info");
  t.innerHTML = "<span>" + (icons[type] || "ℹ") + "</span>" + msg;
  wrap.appendChild(t);
  requestAnimationFrame(function() { t.classList.add("show"); });
  setTimeout(function() { t.classList.remove("show"); setTimeout(function() { t.remove(); }, 350); }, 3500);
}

// ── Date format helper ───────────────────────────
function fmtDate(d) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// ── Role badge helper ────────────────────────────
function roleBadge(role) {
  var map = { student: "b-student", faculty: "b-faculty", hod: "b-hod", admin: "b-admin" };
  return '<span class="badge ' + (map[role] || "b-gray") + '">' + (role||"—") + '</span>';
}

// ── Side navigation HTML (shared) ───────────────
var SIDEBAR_HTML = '<aside class="adm-sidebar">' +
  '<div class="sb-section open"><div class="sb-hd">USER MANAGEMENT<i class="fa-solid fa-chevron-down ch"></i></div><div class="sb-menu">' +
  '<a href="admin-users.html"><i class="fa-solid fa-users"></i> All Users</a>' +
  '<a href="admin-roles.html"><i class="fa-solid fa-user-shield"></i> Roles & RBAC</a>' +
  '<a href="admin-import.html"><i class="fa-solid fa-file-import"></i> Bulk Import</a>' +
  '</div></div>' +
  '<div class="sb-section open"><div class="sb-hd">ACADEMICS & DEPTS<i class="fa-solid fa-chevron-down ch"></i></div><div class="sb-menu">' +
  '<a href="admin-departments.html"><i class="fa-solid fa-building"></i> Departments</a>' +
  '<a href="admin-subjects.html"><i class="fa-solid fa-book"></i> Subjects & Courses</a>' +
  '<a href="admin-timetable.html"><i class="fa-solid fa-calendar-days"></i> Timetable Engine</a>' +
  '</div></div>' +
  '<div class="sb-section open"><div class="sb-hd">SYSTEM CONTROL<i class="fa-solid fa-chevron-down ch"></i></div><div class="sb-menu">' +
  '<a href="admin-attendance.html"><i class="fa-solid fa-clock"></i> Attendance</a>' +
  '<a href="admin-leaves.html"><i class="fa-solid fa-plane-slash"></i> Leave Rules</a>' +
  '<a href="admin-documents.html"><i class="fa-solid fa-file-signature"></i> Document Config</a>' +
  '<a href="admin-exams.html"><i class="fa-solid fa-graduation-cap"></i> Exams & Grading</a>' +
  '</div></div>' +
  '<div class="sb-section open"><div class="sb-hd">COMMUNICATION<i class="fa-solid fa-chevron-down ch"></i></div><div class="sb-menu">' +
  '<a href="admin-announcements.html"><i class="fa-solid fa-bullhorn"></i> Announcements</a>' +
  '</div></div>' +
  '<div class="sb-section open"><div class="sb-hd">DATA & SECURITY<i class="fa-solid fa-chevron-down ch"></i></div><div class="sb-menu">' +
  '<a href="admin-backup.html"><i class="fa-solid fa-database"></i> Backup & Data</a>' +
  '<a href="admin-security.html"><i class="fa-solid fa-list-check"></i> Security & Logs</a>' +
  '<a href="admin-settings.html"><i class="fa-solid fa-gears"></i> App Settings</a>' +
  '</div></div>' +
  '</aside>';

// ── Admin header HTML (shared) ──────────────────
function buildHeader(pageTitle, pageSub) {
  return '<header class="adm-header">' +
    '<img src="../assets/images/LOGO1.png" alt="WizUP" class="adm-logo"/>' +
    '<div><div class="adm-title">' + pageTitle + '</div><div class="adm-sub">' + pageSub + '</div></div>' +
    '<div class="adm-spacer"></div>' +
    '<div class="adm-header-btns">' +
    '<a href="admin-dashboard.html" class="ico-btn" title="Dashboard"><i class="fa-solid fa-house"></i></a>' +
    '<a href="admin-settings.html" class="ico-btn" title="Settings"><i class="fa-solid fa-gear"></i></a>' +
    '<div class="user-chip"><div class="user-avatar" id="userAvatar">A</div><div><div class="user-name" id="userName">Admin</div><div class="user-role">Super Admin</div></div></div>' +
    '<button class="ico-btn danger" onclick="doSignOut()" title="Sign Out"><i class="fa-solid fa-power-off"></i></button>' +
    '</div></header>';
}
