// ─── SUPABASE CLIENT ───────────────────────────────────────────────────────
const SUPABASE_URL = "https://vqxhbfbpqwpdbmgtdcik.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeGhiZmJwcXdwZGJtZ3RkY2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MTY1MTMsImV4cCI6MjA4NzM5MjUxM30.U9wuwWRDsUqKef93fl0C1DLu9l_hQ5zKMT9KhOt24xE";

// Initialize Supabase client (using CDN ESM-compatible approach)
const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ─── AUTH HELPERS ──────────────────────────────────────────────────────────
const getRootPath = () => window.location.pathname.match(/\/(admin|faculty|student|hod|modules)\//) ? "../index.html" : "index.html";

async function signIn(email, password) {
    const { data, error } = await db.auth.signInWithPassword({ email, password });
    return { data, error };
}

async function signOut() {
    await db.auth.signOut();
    localStorage.removeItem("wizup_user");
    window.location.href = getRootPath();
}

async function getSession() {
    const { data } = await db.auth.getSession();
    return data?.session;
}

async function getCurrentProfile() {
    const session = await getSession();
    if (!session) return null;
    const { data } = await db.from("profiles").select("*").eq("id", session.user.id).single();
    return data;
}

// Guard: redirect to index if not logged in
async function requireAuth(allowedRoles) {
    const session = await getSession();
    if (!session) { window.location.href = getRootPath(); return null; }
    
    // Try to get profile, but don't redirect to index immediately if it's just slow
    const profile = await getCurrentProfile();
    if (!profile) {
        console.warn("Auth Guard: Profile not found yet.");
        return null;
    }

    if (allowedRoles && !allowedRoles.includes(profile.role)) {
        console.warn(`Auth Guard: Role '${profile.role}' not in permitted list [${allowedRoles}]. Redirecting to hub...`);
        window.location.href = getRootPath(); 
        return null;
    }
    return profile;
}

// Format date nicely
function fmtDate(d) {
    if (!d) return "—";
    return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// Show toast notification
function showToast(msg, type = "success") {
    const t = document.createElement("div");
    t.className = "wz-toast wz-toast-" + type;
    t.textContent = msg;
    t.style.cssText = `position:fixed;bottom:24px;right:24px;z-index:9999;padding:12px 20px;border-radius:12px;font-size:13px;font-weight:600;color:#fff;background:${type === "success" ? "#22c55e" : type === "error" ? "#ef4444" : "#f59e0b"};box-shadow:0 8px 24px rgba(0,0,0,.4);animation:slideUp .3s ease;pointer-events:none`;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), 3200);
}

// Inject global toast animation
const style = document.createElement("style");
style.textContent = `@keyframes slideUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}`;
document.head.appendChild(style);
