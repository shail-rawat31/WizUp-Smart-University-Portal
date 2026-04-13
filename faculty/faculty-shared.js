/* faculty-shared.js — injected via <script src> on every faculty page */
const SUPABASE_URL = "https://vqxhbfbpqwpdbmgtdcik.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE";
const db = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Toast
function showToast(msg, type = "success") {
  let wrap = document.getElementById("toast-wrap");
  if (!wrap) { wrap = document.createElement("div"); wrap.id = "toast-wrap"; document.body.appendChild(wrap); }
  const t = document.createElement("div");
  const icons = { success: "✓", error: "✗", info: "ℹ" };
  t.className = `toast ${type}`;
  t.innerHTML = `<span>${icons[type]||"ℹ"}</span>${msg}`;
  wrap.appendChild(t);
  requestAnimationFrame(() => t.classList.add("show"));
  setTimeout(() => { t.classList.remove("show"); setTimeout(() => t.remove(), 350); }, 3200);
}

// Require auth + role check
async function requireAuth(roles = ["faculty"]) {
  const { data: { session } } = await db.auth.getSession();
  if (!session) { window.location.href = "faculty-signin.html"; return null; }
  const { data: profile } = await db.from("profiles").select("*").eq("id", session.user.id).single();
  if (!profile || !roles.includes(profile.role)) { window.location.href = "../index.html"; return null; }
  document.body.style.display = "block";
  fillHeader(profile);
  return profile;
}

// Fill header user info
function fillHeader(profile) {
  const name = profile.full_name || "Faculty";
  const fn = name.split(" ")[0];
  const el = document.getElementById("uName");
  const av = document.getElementById("uAvatar");
  if (el) el.textContent = fn;
  if (av) av.textContent = fn[0].toUpperCase();
}

// Sign out
async function doSignOut() {
  await db.auth.signOut();
  window.location.href = "../index.html";
}

// Sidebar toggle
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".sidebar-header").forEach(h => {
    h.addEventListener("click", () => h.parentElement.classList.toggle("open"));
  });
  // Mark active link
  const path = window.location.pathname.split("/").pop();
  document.querySelectorAll(".sidebar-menu a").forEach(a => {
    if (a.getAttribute("href") === path) a.classList.add("active");
  });
  // Clock
  const clk = document.getElementById("clock");
  if (clk) {
    const tick = () => { clk.textContent = new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", second: "2-digit" }); };
    setInterval(tick, 1000); tick();
  }
});

// Format date helper
function fmtDate(d) { if (!d) return "—"; return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }); }
