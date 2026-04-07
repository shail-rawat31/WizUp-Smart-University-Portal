-- =========================================================================================
-- WIZUP UNIVERSITY PORTAL: FULL RESET & PRODUCTION SETUP
-- Role-based System (Student, Faculty, HOD, Admin)
-- Run this ONCE in the Supabase SQL Editor.
-- =========================================================================================

-- ============================================================
-- 1. FULL RESET (Clean Dependencies Safely)
-- ============================================================
-- Drops everything cleanly to guarantee no conflicts
DO $$ DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
    FOR r IN (SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public') LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.routine_name) || ' CASCADE';
    END LOOP;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- ============================================================
-- 2. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 3. SCHEMA DEFINITION (CORE TABLES)
-- ============================================================

-- A. System Tables
CREATE TABLE public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    duration_years INTEGER DEFAULT 3,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- B. Unified Profiles
-- Using a unified profiles table ensures frontend SPA integrations don't break, 
-- while elegantly handling student/faculty properties in normalized space.
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('student', 'faculty', 'hod', 'admin')) DEFAULT 'student',
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    -- Role Specific Fields
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    roll_no TEXT UNIQUE,                -- Students only
    current_semester INTEGER,           -- Students only
    batch TEXT,                         -- Students only
    employee_code TEXT UNIQUE,          -- Staff/Faculty only
    designation TEXT,                   -- Staff/Faculty only
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_profiles_role ON public.profiles(role);

-- C. Academics
CREATE TABLE public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE CASCADE,
    semester INTEGER NOT NULL,
    credits INTEGER DEFAULT 3,
    faculty_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.subject_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    assigned_date DATE DEFAULT CURRENT_DATE,
    CONSTRAINT unique_allocation UNIQUE (student_id, subject_id)
);

-- D. Attendance Tracking (with constraints to prevent duplicates)
CREATE TABLE public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'leave')),
    marked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_attendance_per_day UNIQUE (student_id, subject_id, date) 
);

-- E. Marks Management
CREATE TABLE public.marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    exam_type TEXT NOT NULL CHECK (exam_type IN ('mst_marks', 'assignment_marks', 'attendance_marks', 'final')),
    marks_obtained NUMERIC(5,2) DEFAULT 0,
    max_marks NUMERIC(5,2) NOT NULL,
    graded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_mark_record UNIQUE (student_id, subject_id, exam_type)
);

-- F. Leave Workflow
CREATE TABLE public.leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('medical', 'casual', 'duty')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    days_count INTEGER GENERATED ALWAYS AS (end_date - start_date + 1) STORED,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    medical_required BOOLEAN DEFAULT FALSE,
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_leave_dates CHECK (end_date >= start_date)
);

-- G. System Tables
CREATE TABLE public.timetable (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    day_of_week TEXT NOT NULL CHECK (day_of_week IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room TEXT NOT NULL
);

CREATE TABLE public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    posted_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_role TEXT CHECK (target_role IN ('all', 'student', 'faculty', 'hod')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- H. Advanced Academic & Extracurricular (Derived from ERD)
CREATE TABLE public.schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Alter departments to physically belong to a school hierarchy
ALTER TABLE public.departments ADD COLUMN school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL;

CREATE TABLE public.academic_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_name TEXT NOT NULL, 
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

CREATE TABLE public.semesters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES public.academic_sessions(id) ON DELETE CASCADE,
    semester_type TEXT NOT NULL CHECK (semester_type IN ('Fall', 'Spring', 'Summer')),
    start_date DATE,
    end_date DATE
);

CREATE TABLE public.course_dependencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    prerequisite_subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    CONSTRAINT unique_dependency UNIQUE (subject_id, prerequisite_subject_id)
);

CREATE TABLE public.student_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    organizer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- I. Fully Maxed Advance University Modules
-- 1. Financial/Fee Management
CREATE TABLE public.fee_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    due_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'overdue')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES public.fee_invoices(id) ON DELETE CASCADE,
    amount_paid NUMERIC(10,2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('card', 'netbanking', 'upi', 'cash')),
    transaction_id TEXT UNIQUE NOT NULL,
    payment_date TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Library System
CREATE TABLE public.library_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    isbn TEXT UNIQUE,
    total_copies INTEGER DEFAULT 1,
    available_copies INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.library_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID REFERENCES public.library_books(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    issue_date DATE DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE,
    fine_amount NUMERIC(5,2) DEFAULT 0,
    status TEXT NOT NULL CHECK (status IN ('issued', 'returned', 'lost')) DEFAULT 'issued'
);

-- 3. Hostel Management
CREATE TABLE public.hostels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    warden_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    total_rooms INTEGER NOT NULL
);

CREATE TABLE public.hostel_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hostel_id UUID REFERENCES public.hostels(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_number TEXT NOT NULL,
    allocation_date DATE DEFAULT CURRENT_DATE,
    CONSTRAINT unique_room_allocation UNIQUE (student_id)
);

-- 4. Transport System
CREATE TABLE public.transport_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_name TEXT NOT NULL UNIQUE,
    vehicle_number TEXT NOT NULL,
    driver_name TEXT,
    capacity INTEGER NOT NULL
);

CREATE TABLE public.transport_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id UUID REFERENCES public.transport_routes(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    pickup_point TEXT NOT NULL,
    CONSTRAINT unique_transport_allocation UNIQUE (student_id)
);

-- 5. Placement Cell
CREATE TABLE public.placement_companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    industry TEXT,
    website TEXT
);

CREATE TABLE public.placement_drives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.placement_companies(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    eligibility_criteria TEXT,
    drive_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.placement_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drive_id UUID REFERENCES public.placement_drives(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('applied', 'shortlisted', 'interviewed', 'selected', 'rejected')) DEFAULT 'applied',
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_drive_application UNIQUE (drive_id, student_id)
);

-- 6. Online Examinations
CREATE TABLE public.online_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE TABLE public.test_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES public.online_tests(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_option TEXT NOT NULL,
    marks NUMERIC(4,2) DEFAULT 1
);

CREATE TABLE public.test_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID REFERENCES public.online_tests(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    answers JSONB NOT NULL, 
    score_achieved NUMERIC(5,2),
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_test_submission UNIQUE (test_id, student_id)
);

-- 7. Feedback & Disciplinary 
CREATE TABLE public.feedback_forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_faculty_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    comments TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.disciplinary_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    incident_date DATE NOT NULL,
    description TEXT NOT NULL,
    action_taken TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'resolved')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS) - ZERO RECURSION using JWT
-- ============================================================

-- Activate RLS globally
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.fee_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hostels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hostel_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_drives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinary_records ENABLE ROW LEVEL SECURITY;

-- Base Universal Policy: Admins access everything
CREATE POLICY "Admin All Profiles" ON public.profiles FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Departments" ON public.departments FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Courses" ON public.courses FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Subjects" ON public.subjects FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Allocations" ON public.subject_allocations FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Students see own allocations" ON public.subject_allocations FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Faculty see respective allocations" ON public.subject_allocations FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'faculty' AND subject_id IN (SELECT id FROM public.subjects WHERE faculty_id = auth.uid()) );
CREATE POLICY "Admin All Attendance" ON public.attendance FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Marks" ON public.marks FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Leaves" ON public.leave_requests FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Timetable" ON public.timetable FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Announcements" ON public.announcements FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Schools" ON public.schools FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Sessions" ON public.academic_sessions FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Semesters" ON public.semesters FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Dependencies" ON public.course_dependencies FOR ALL USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'admin' );
CREATE POLICY "Admin All Fees" ON public.fee_invoices FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Payments" ON public.fee_payments FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Lib Books" ON public.library_books FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Lib Trans" ON public.library_transactions FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Hostels" ON public.hostels FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All H Allocations" ON public.hostel_allocations FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Routes" ON public.transport_routes FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All T Allocations" ON public.transport_allocations FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Placements" ON public.placement_companies FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All P Drives" ON public.placement_drives FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All P Apps" ON public.placement_applications FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Tests" ON public.online_tests FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Test Qs" ON public.test_questions FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Test Subs" ON public.test_submissions FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Feedback" ON public.feedback_forms FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');
CREATE POLICY "Admin All Discipline" ON public.disciplinary_records FOR ALL USING ((auth.jwt()->'user_metadata'->>'role')::text = 'admin');

-- Global Read Access for essential reference tables
CREATE POLICY "Global Read Depts" ON public.departments FOR SELECT USING (true);
CREATE POLICY "Global Read Courses" ON public.courses FOR SELECT USING (true);
CREATE POLICY "Global Read Subjects" ON public.subjects FOR SELECT USING (true);
CREATE POLICY "Global Read Timetable" ON public.timetable FOR SELECT USING (true);
CREATE POLICY "Global Read Schools" ON public.schools FOR SELECT USING (true);
CREATE POLICY "Global Read Sessions" ON public.academic_sessions FOR SELECT USING (true);
CREATE POLICY "Global Read Semesters" ON public.semesters FOR SELECT USING (true);
CREATE POLICY "Global Read Course Dependencies" ON public.course_dependencies FOR SELECT USING (true);
CREATE POLICY "Global Read Groups" ON public.student_groups FOR SELECT USING (true);
CREATE POLICY "Global Read Events" ON public.events FOR SELECT USING (true);
CREATE POLICY "Global Read Lib Books" ON public.library_books FOR SELECT USING (true);
CREATE POLICY "Global Read P Companies" ON public.placement_companies FOR SELECT USING (true);
CREATE POLICY "Global Read P Drives" ON public.placement_drives FOR SELECT USING (true);
CREATE POLICY "Global Read Hostels" ON public.hostels FOR SELECT USING (true);
CREATE POLICY "Global Read Routes" ON public.transport_routes FOR SELECT USING (true);

-- Profiles
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users edit own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "HOD see all profiles in dept" ON public.profiles FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'hod' );
CREATE POLICY "Faculty see all students" ON public.profiles FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'faculty' AND role = 'student' );

-- Attendance
CREATE POLICY "Students see own attendance" ON public.attendance FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Faculty mark attendance" ON public.attendance FOR INSERT WITH CHECK (
    (auth.jwt()->'user_metadata'->>'role')::text = 'faculty' AND 
    auth.uid() IN (SELECT faculty_id FROM public.subjects WHERE id = subject_id)
);
CREATE POLICY "HOD read all attendance" ON public.attendance FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'hod' );

-- Marks
CREATE POLICY "Students see own marks" ON public.marks FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Faculty upload marks" ON public.marks FOR INSERT WITH CHECK (
    (auth.jwt()->'user_metadata'->>'role')::text = 'faculty' AND 
    auth.uid() IN (SELECT faculty_id FROM public.subjects WHERE id = subject_id)
);
CREATE POLICY "HOD read all marks" ON public.marks FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'hod' );

-- Leave Requests
CREATE POLICY "Users push and view own leaves" ON public.leave_requests FOR ALL USING (auth.uid() = requested_by);
CREATE POLICY "HOD approve leaves" ON public.leave_requests FOR UPDATE USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'hod' );
CREATE POLICY "HOD view all leaves" ON public.leave_requests FOR SELECT USING ( (auth.jwt()->'user_metadata'->>'role')::text = 'hod' );

-- Announcements & Notifications
CREATE POLICY "HOD and Admin read announcements" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

-- Groups & Events Extracurricular Policies
CREATE POLICY "Authenticated users can create groups" ON public.student_groups FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Group creators can update their groups" ON public.student_groups FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Authenticated users can create events" ON public.events FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Event organizers can update their events" ON public.events FOR UPDATE USING (auth.uid() = organizer_id);

-- Maxed Modules Student Access Policies
CREATE POLICY "Student read own fees" ON public.fee_invoices FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student read own lib" ON public.library_transactions FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student read own hostel" ON public.hostel_allocations FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student read own transport" ON public.transport_allocations FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student read own apps" ON public.placement_applications FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student apply placements" ON public.placement_applications FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Student read tests" ON public.online_tests FOR SELECT USING (true);
CREATE POLICY "Student read test Qs" ON public.test_questions FOR SELECT USING (true);
CREATE POLICY "Student submit test" ON public.test_submissions FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Student read own subs" ON public.test_submissions FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Student insert feedback" ON public.feedback_forms FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Student read own discipline" ON public.disciplinary_records FOR SELECT USING (auth.uid() = student_id);

-- ============================================================
-- 5. AUTOMATION (TRIGGERS & FUNCTIONS)
-- ============================================================

-- A. Auto-Create Profile Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, roll_no, employee_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
    NEW.raw_user_meta_data->>'roll_no',
    NEW.raw_user_meta_data->>'employee_code'
  ) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trigger_auto_create_profile AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- B. Leave Rule Enforcement
CREATE OR REPLACE FUNCTION public.check_leave_rules() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.days_count >= 3 AND NEW.days_count <= 10 THEN
    NEW.medical_required := TRUE;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trigger_check_leave_rule BEFORE INSERT ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.check_leave_rules();


-- ============================================================
-- 6. SYSTEM SEED (Inject Initial Data)
-- ============================================================
DO $$ 
DECLARE
  dept_id UUID := gen_random_uuid();
  course_id UUID := gen_random_uuid();
  fac_rahul UUID := gen_random_uuid();
  fac_jasleen UUID := gen_random_uuid();
  fac_anup UUID := gen_random_uuid();
  fac_jasmeet UUID := gen_random_uuid();
  fac_shivani UUID := gen_random_uuid();
  fac_tarsem UUID := gen_random_uuid();
  fac_bhawan UUID := gen_random_uuid();
  fac_ambika UUID := gen_random_uuid();
  fac_gurjit UUID := gen_random_uuid();
  fac_kiran UUID := gen_random_uuid();
  hod1 UUID := gen_random_uuid();
  adm1 UUID := gen_random_uuid();
  
  sub_aptitude UUID := gen_random_uuid();
  sub_multimedia UUID := gen_random_uuid();
  sub_dbms_lab UUID := gen_random_uuid();
  sub_dbms UUID := gen_random_uuid();
  sub_soft_skill UUID := gen_random_uuid();
  sub_ai UUID := gen_random_uuid();
  sub_auto UUID := gen_random_uuid();
  sub_french UUID := gen_random_uuid();
  sub_gender UUID := gen_random_uuid();
  sub_tour UUID := gen_random_uuid();
  
  student_ids UUID[] := ARRAY(SELECT gen_random_uuid() FROM generate_series(1, 40));
  i INTEGER; s UUID;
  auth_pw TEXT := crypt('password123', gen_salt('bf', 10));
  now_ts TIMESTAMPTZ := NOW();
  default_inst UUID := '00000000-0000-0000-0000-000000000000';
  app_meta JSONB := '{"provider":"email","providers":["email"]}'::jsonb;
BEGIN

  -- Clean old test users to prevent unique constraint failures
  DELETE FROM auth.users WHERE email LIKE '%@wizup.edu';

  -- Departments & Courses
  INSERT INTO public.departments (id, name) VALUES (dept_id, 'Bachelor of Computer Applications (BCA)');
  INSERT INTO public.courses (id, name, department_id, duration_years) VALUES (course_id, 'BCA', dept_id, 3);

  -- Admin Seed
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at)
  VALUES (adm1, default_inst, 'authenticated', 'authenticated', 'admin@wizup.edu', auth_pw, now_ts, now_ts, '{"role":"admin","full_name":"Super Admin"}', app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) 
  VALUES (gen_random_uuid(), adm1, adm1, format('{"sub":"%s","email":"%s"}', adm1, 'admin@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- HOD Seed
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at)
  VALUES (hod1, default_inst, 'authenticated', 'authenticated', 'hod.bca@wizup.edu', auth_pw, now_ts, now_ts, '{"role":"hod","full_name":"Dr. HOD BCA","employee_code":"HOD_BCA"}', app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) 
  VALUES (gen_random_uuid(), hod1, hod1, format('{"sub":"%s","email":"%s"}', hod1, 'hod.bca@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- Faculty Seeds (Extracted from 23BCA-1 Timetable)
  -- 1. Mr. Rahul singh E15602
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_rahul, default_inst, 'authenticated', 'authenticated', 'E15602@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Mr. Rahul Singh', 'employee_code', 'E15602')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_rahul, fac_rahul, format('{"sub":"%s","email":"%s"}', fac_rahul, 'E15602@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 2. Ms Jasleen kaur E16528
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_jasleen, default_inst, 'authenticated', 'authenticated', 'E16528@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Jasleen Kaur', 'employee_code', 'E16528')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_jasleen, fac_jasleen, format('{"sub":"%s","email":"%s"}', fac_jasleen, 'E16528@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 3. Mr. Anup Kumar Singh E13456
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_anup, default_inst, 'authenticated', 'authenticated', 'E13456@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Mr. Anup Kumar Singh', 'employee_code', 'E13456')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_anup, fac_anup, format('{"sub":"%s","email":"%s"}', fac_anup, 'E13456@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 4. Ms.Jasmeet Kaur E5466
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_jasmeet, default_inst, 'authenticated', 'authenticated', 'E5466@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Jasmeet Kaur', 'employee_code', 'E5466')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_jasmeet, fac_jasmeet, format('{"sub":"%s","email":"%s"}', fac_jasmeet, 'E5466@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 5. Ms Shivani Chadha E16628
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_shivani, default_inst, 'authenticated', 'authenticated', 'E16628@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Shivani Chadha', 'employee_code', 'E16628')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_shivani, fac_shivani, format('{"sub":"%s","email":"%s"}', fac_shivani, 'E16628@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 6. Er.Tarsem Singh E4148
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_tarsem, default_inst, 'authenticated', 'authenticated', 'E4148@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Er. Tarsem Singh', 'employee_code', 'E4148')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_tarsem, fac_tarsem, format('{"sub":"%s","email":"%s"}', fac_tarsem, 'E4148@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 7. Ms.Bhawan Preet Kaur E16432
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_bhawan, default_inst, 'authenticated', 'authenticated', 'E16432@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Bhawan Preet Kaur', 'employee_code', 'E16432')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_bhawan, fac_bhawan, format('{"sub":"%s","email":"%s"}', fac_bhawan, 'E16432@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 8. Ms. Ambika E16450
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_ambika, default_inst, 'authenticated', 'authenticated', 'E16450@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Ambika', 'employee_code', 'E16450')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_ambika, fac_ambika, format('{"sub":"%s","email":"%s"}', fac_ambika, 'E16450@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 9. Ms.Gurjit Kaur Parmar E18408
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_gurjit, default_inst, 'authenticated', 'authenticated', 'E18408@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Ms. Gurjit Kaur Parmar', 'employee_code', 'E18408')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_gurjit, fac_gurjit, format('{"sub":"%s","email":"%s"}', fac_gurjit, 'E18408@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- 10. Dr Kiran Shashwat E12368
  INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES 
  (fac_kiran, default_inst, 'authenticated', 'authenticated', 'E12368@wizup.edu', auth_pw, now_ts, now_ts, json_build_object('role', 'faculty', 'full_name', 'Dr. Kiran Shashwat', 'employee_code', 'E12368')::jsonb, app_meta, FALSE, now_ts, now_ts);
  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) VALUES (gen_random_uuid(), fac_kiran, fac_kiran, format('{"sub":"%s","email":"%s"}', fac_kiran, 'E12368@wizup.edu')::jsonb, 'email', now_ts, now_ts);

  -- Setup Profile FKs after triggers complete
  UPDATE public.profiles SET department_id = dept_id;

  -- Subjects
  INSERT INTO public.subjects (id, subject_code, name, department_id, semester, credits, faculty_id) VALUES
  (sub_aptitude, '23TDT-274', 'Aptitude_TPP', dept_id, 3, 3, fac_rahul),
  (sub_multimedia, '23CAH-256', 'Multimedia and Animation', dept_id, 3, 4, fac_jasleen),
  (sub_dbms_lab, '23CAP-252', 'Database Management System Lab', dept_id, 3, 2, fac_anup),
  (sub_dbms, '23CAT-251', 'Database Management System', dept_id, 3, 4, fac_anup),
  (sub_soft_skill, '23TDP-273', 'Soft Skill_TPP', dept_id, 3, 2, fac_jasmeet),
  (sub_ai, '23CAT-253', 'Artificial Intelligence', dept_id, 3, 4, fac_shivani),
  (sub_auto, 'MEO-361', 'Automobile Engineering', dept_id, 3, 3, fac_tarsem),
  (sub_french, 'LFO-441', 'French', dept_id, 3, 3, fac_bhawan),
  (sub_gender, '23UCT-297', 'Gender Equality and Empowerment', dept_id, 3, 2, fac_ambika),
  (sub_tour, 'TTO-202', 'Professional Tour and Planning', dept_id, 3, 3, fac_kiran);

  -- Timetable (23BCA-1) extracted from schedule
  INSERT INTO public.timetable (subject_id, day_of_week, start_time, end_time, room) VALUES
  -- Monday
  (sub_aptitude, 'Monday', '09:55:00', '10:40:00', 'Hall-414_E2Block'),
  (sub_multimedia, 'Monday', '11:25:00', '12:10:00', 'Lab-307_E2Block'),
  (sub_dbms_lab, 'Monday', '12:10:00', '12:55:00', 'Lab-306_E2Block'),
  (sub_french, 'Monday', '13:40:00', '14:25:00', 'Hall-414_E2Block'),
  (sub_soft_skill, 'Monday', '14:25:00', '15:10:00', 'Lab-105_E2Block'),
  -- Tuesday
  (sub_ai, 'Tuesday', '09:55:00', '10:40:00', 'Hall-404_E2Block'),
  (sub_auto, 'Tuesday', '10:40:00', '11:25:00', 'Hall-412_E2Block'),
  (sub_multimedia, 'Tuesday', '11:25:00', '12:10:00', 'Lab-209_E2Block'),
  (sub_gender, 'Tuesday', '13:40:00', '14:25:00', 'Hall-310_E2Block'),
  (sub_dbms, 'Tuesday', '14:25:00', '15:10:00', 'Hall-310_E2Block'),
  -- Wednesday
  (sub_soft_skill, 'Wednesday', '09:55:00', '10:40:00', 'Lab-101_E2Block'),
  (sub_french, 'Wednesday', '11:25:00', '12:10:00', 'Hall-312_E2Block'),
  (sub_multimedia, 'Wednesday', '13:40:00', '14:25:00', 'Lab-304_E2Block'),
  (sub_tour, 'Wednesday', '14:25:00', '15:10:00', 'Hall-310_E2Block'),
  -- Thursday
  (sub_dbms, 'Thursday', '10:40:00', '11:25:00', 'Hall-504_E2Block'),
  (sub_auto, 'Thursday', '11:25:00', '12:10:00', 'Hall-228_E2Block'),
  (sub_ai, 'Thursday', '13:40:00', '14:25:00', 'Hall-309_E2Block'),
  (sub_dbms_lab, 'Thursday', '14:25:00', '15:10:00', 'Lab-307_E2Block'),
  -- Friday
  (sub_dbms, 'Friday', '09:55:00', '10:40:00', 'Hall-311_E2Block'),
  (sub_multimedia, 'Friday', '10:40:00', '11:25:00', 'Hall-117_E2Block'),
  (sub_tour, 'Friday', '11:25:00', '12:10:00', 'Hall-310_E2Block'),
  (sub_french, 'Friday', '12:10:00', '12:55:00', 'Hall-404_E2Block'),
  (sub_soft_skill, 'Friday', '13:40:00', '14:25:00', 'Lab-101_E2Block');

  -- Student Seeds (40 Total in Batch 23BCA-1)
  FOR i IN 1..40 LOOP
    s := student_ids[i];
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_sent_at, raw_user_meta_data, raw_app_meta_data, is_super_admin, created_at, updated_at) VALUES (
      s, default_inst, 'authenticated', 'authenticated', '23bca1' || LPAD(i::text, 3, '0') || '@wizup.edu', auth_pw, now_ts, now_ts, 
      json_build_object('role', 'student', 'full_name', 'Student ' || i, 'roll_no', '23BCA1' || LPAD(i::text, 3, '0'), 'batch', '23BCA-1')::jsonb, 
      app_meta, FALSE, now_ts, now_ts
    );
    INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at) 
    VALUES (gen_random_uuid(), s, s, format('{"sub":"%s","email":"%s"}', s, '23bca1' || LPAD(i::text, 3, '0') || '@wizup.edu')::jsonb, 'email', now_ts, now_ts);

    -- Link student to all 10 subjects from the timetable
    INSERT INTO public.subject_allocations (student_id, subject_id) VALUES 
    (s, sub_aptitude), (s, sub_multimedia), (s, sub_dbms_lab), (s, sub_dbms), (s, sub_soft_skill), 
    (s, sub_ai), (s, sub_auto), (s, sub_french), (s, sub_gender), (s, sub_tour);
    
  END LOOP;

  -- Fix GoTrue "Scan error" panics (500 Database error) when tokens are NULL
  UPDATE auth.users 
  SET confirmation_token = '',
      recovery_token = '',
      email_change_token_new = '',
      email_change = '';

END $$;

-- Hard wipe the schema cache on PostgREST so the Web Frontend syncs cleanly
NOTIFY pgrst, 'reload schema';

-- SETUP COMPLETED SUCCESSFULLY
