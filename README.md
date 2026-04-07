# WizUP - University Management Portal 🎓

WizUP is a cutting-edge next-generation University Management Portal designed to provide a unified, secure, and personalized digital campus experience. Engineered for speed, security, and aesthetics, the portal effortlessly connects Students, Faculty, HODs, and Administrators under a single pane of glass.

![UI Theme](https://img.shields.io/badge/UI-Premium_Glassmorphism-00d2ff?style=flat-square)
![Database](https://img.shields.io/badge/Database-Supabase_PostgreSQL-47b27e?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Vanilla_SPA-f1c40f?style=flat-square)

## 🌟 Key Features

* **Role-Based Access Control System (RBAC):** Distinct routing, UI, and Database-level Row-Level-Security (RLS) policies for Administration, Head of Departments (HOD), Faculty, and Students.
* **Premium Glassmorphic Aesthetics:** Tailored custom CSS properties encompassing drop backdrops, blurred glass layers, and ambient glows, built without heavy CSS frameworks to ensure maximum performance.
* **Supabase Integration:** Live authentication using GoTrue, real-time database CRUD mappings utilizing Supabase JS Client v2.
* **Scale-Ready Architecture:** Over 45 logical sub-component pages segregated efficiently to maximize multi-page structural velocity while maintaining SPA-like rendering.

## 📂 Project Structure

To maintain clean logical separation and avoid link-pollution, the project breaks down horizontally by Auth Role:

```text
WizUP/
├── admin/          # Admin Dashboard & System-level configs (RBAC, subjects, server logs)
├── faculty/        # Faculty Portal (Attendance marking, grading arrays, student directories)
├── student/        # Student Portal (Library, Leave applying, Timetables, Online Exams)
├── hod/            # Head of Department Hub (Escalations, Faculty evaluation charts)
├── assets/         # Unified CSS design systems, JS drivers, and static image assets
├── sql/            # Supabase migration algorithms and master setups
├── index.html      # Gateway login interface auto-routing via JWT sessions
└── README.md
```

## 🛠️ Technology Stack

* **Frontend:** HTML5, Premium Vanilla CSS (Glassmorphism), Vanilla JavaScript (ESM)
* **Backend Backend-as-a-Service:** Supabase
* **Database:** PostgreSQL (with JSONB profiling, Triggers, and RLS)
* **Icons:** FontAwesome V6
* **Typography:** Inter & Outfit (Google Fonts)

## 🚀 Getting Started

### 1. Database Initialization
1. Deploy a new project on [Supabase](https://supabase.com).
2. Execute the `sql/wizup_master_setup.sql` script within your Supabase SQL Editor. This completely drops any conflicting architectures and provisions the core Tables, Foreign Keys, Functions, and mandatory RLS policies.

### 2. Environment Variables
1. Replace the `SUPABASE_URL` and `SUPABASE_ANON_KEY` inside `assets/js/supabase.js` with your distinct credentials obtained from the Supabase API Settings.

### 3. Running Locally
Because this project heavily relies on secure module importation and browser API cross-origins:
1. Open the project folder in VS Code.
2. Launch via the **Live Server** extension (Do NOT directly click `index.html` via the `file:///` protocol).
3. The platform will serve at `http://127.0.0.1:5500`.

## 🔐 Authentication Sandbox Workflow
*(Note: As email SMTP auto-confirmation is turned off, users must be seeded or authenticated natively on the backend before login).*
1. Navigate to the `auth/users` dashboard in Supabase.
2. Click **Add User** -> Insert login credentials -> Check "Auto Conform".
3. Navigate to the `public.profiles` table and modify their `role` column to either `admin`, `hod`, `faculty`, or `student`.
4. Return to the portal and login securely. 

---
*Developed with pristine architecture and modern web aesthetics.*
