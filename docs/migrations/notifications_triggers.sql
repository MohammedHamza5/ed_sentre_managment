-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Phase 6 - System Integration (Sync & Notifications) 🧠
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Ensure Notifications Table Exists
-- (Based on NotificationRepository.dart)
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    recipient_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    body text NOT NULL,
    category text DEFAULT 'general', -- 'attendance', 'exam', 'system'
    priority text DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
    data jsonb DEFAULT '{}'::jsonb,
    is_read boolean DEFAULT false,
    read_at timestamptz,
    center_id uuid, -- Optional: links to specific center
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS: Users can see their own notifications
CREATE POLICY "Users can view their own notifications" 
ON public.notifications FOR SELECT 
USING (auth.uid() = recipient_id);

-- 2. Trigger: Attendance Notification (Student & Parent) 🏫
CREATE OR REPLACE FUNCTION public.handle_new_attendance()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_name text;
    v_course_name text;
    v_parent_id uuid;
    v_title text;
    v_body text;
BEGIN
    -- Get Student Name & Course Name
    -- Assuming 'profiles' table stores user names
    SELECT p.full_name, c.name 
    INTO v_student_name, v_course_name
    FROM public.profiles p
    JOIN public.attendance_sessions s ON s.id = NEW.session_id
    JOIN public.groups g ON g.id = s.group_id
    JOIN public.courses c ON c.id = g.course_id
    WHERE p.id = NEW.student_id;

    -- 1. Notify STUDENT
    IF NEW.status = 'present' THEN
        v_title := 'تم تسجيل الحضور ✅';
        v_body := 'تم تسجيل حضورك في حصة ' || v_course_name;
    ELSE
        v_title := 'تسجيل غياب ❌';
        v_body := 'تم تسجيل غيابك عن حصة ' || v_course_name;
    END IF;

    INSERT INTO public.notifications (recipient_id, title, body, category, priority, data, center_id)
    VALUES (
        NEW.student_id, 
        v_title, 
        v_body, 
        'attendance', 
        'high', 
        jsonb_build_object('attendance_id', NEW.id, 'session_id', NEW.session_id),
        NEW.center_id
    );

    -- 2. Notify PARENT (if linked)
    -- Find parent linked to this student
    -- Assuming 'parent_student_links' table exists (need confirmation, otherwise skip)
    BEGIN
        SELECT parent_id INTO v_parent_id
        FROM public.parent_student_links
        WHERE student_id = NEW.student_id
        LIMIT 1;

        IF v_parent_id IS NOT NULL THEN
            IF NEW.status = 'present' THEN
                v_title := 'وصول الطالب للمركز 📍';
                v_body := 'وصل ' || v_student_name || ' لحضور حصة ' || v_course_name;
            ELSE
                v_title := 'غياب الطالب ⚠️';
                v_body := 'تغيب ' || v_student_name || ' عن حصة ' || v_course_name;
            END IF;

            INSERT INTO public.notifications (recipient_id, title, body, category, priority, data, center_id)
            VALUES (
                v_parent_id, 
                v_title, 
                v_body, 
                'attendance', 
                'high', 
                jsonb_build_object('student_id', NEW.student_id, 'attendance_id', NEW.id),
                NEW.center_id
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Ignore parent notification errors if table missing
    END;

    RETURN NEW;
END;
$$;

-- Drop trigger if exists to avoid duplication
DROP TRIGGER IF EXISTS on_attendance_created ON public.attendance;

CREATE TRIGGER on_attendance_created
AFTER INSERT ON public.attendance
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_attendance();


-- 3. Trigger: Exam Result Notification (Student & Parent) 📝
-- Assuming table 'grades' exists based on repository
CREATE OR REPLACE FUNCTION public.handle_new_grade()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_name text;
    v_exam_title text;
    v_course_name text;
    v_parent_id uuid;
    v_title text;
    v_body text;
BEGIN
    -- Get Details
    SELECT p.full_name, c.name 
    INTO v_student_name, v_course_name
    FROM public.profiles p
    LEFT JOIN public.courses c ON c.id = NEW.course_id
    WHERE p.id = NEW.student_id;

    v_exam_title := COALESCE(NEW.exam_name, 'الاختبار');

    -- 1. Notify STUDENT
    v_title := 'نتيجة جديدة 📄';
    v_body := 'تم رصد درجة ' || v_exam_title || ' في مادة ' || COALESCE(v_course_name, 'العامة');

    INSERT INTO public.notifications (recipient_id, title, body, category, priority, data)
    VALUES (
        NEW.student_id, 
        v_title, 
        v_body, 
        'grades', 
        'high', 
        jsonb_build_object('grade_id', NEW.id, 'score', NEW.score)
    );

    -- 2. Notify PARENT
    BEGIN
        SELECT parent_id INTO v_parent_id
        FROM public.parent_student_links
        WHERE student_id = NEW.student_id
        LIMIT 1;

        IF v_parent_id IS NOT NULL THEN
            v_title := 'نتيجة الطالب 📊';
            v_body := 'حصل ' || v_student_name || ' على ' || NEW.score || '/' || NEW.max_score || ' في ' || v_exam_title;

            INSERT INTO public.notifications (recipient_id, title, body, category, priority, data)
            VALUES (
                v_parent_id, 
                v_title, 
                v_body, 
                'grades', 
                'high', 
                jsonb_build_object('student_id', NEW.student_id, 'grade_id', NEW.id)
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Ignore errors
    END;

    RETURN NEW;
END;
$$;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS on_grade_created ON public.grades;

CREATE TRIGGER on_grade_created
AFTER INSERT ON public.grades
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_grade();
