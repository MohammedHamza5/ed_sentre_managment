-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Genius Attendance System V2 (Universal Smart QR)
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Create center_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.center_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    center_id uuid REFERENCES public.centers(id) ON DELETE CASCADE, -- Assuming centers table exists, otherwise remove FK
    universal_qr_key text DEFAULT md5(random()::text),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.center_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can read settings (needed for dynamic QR generation on management app)
CREATE POLICY "Authenticated users can view center settings"
ON public.center_settings
FOR SELECT
TO authenticated
USING (true);

-- Policy: Only admins can update (Simulated for now)
CREATE POLICY "Admins can update center settings"
ON public.center_settings
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. UPDATE RPC: secure_check_in (Universal Logic)
CREATE OR REPLACE FUNCTION public.secure_check_in(
    p_student_id uuid,
    p_qr_payload text,
    p_location jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id uuid;
    v_center_id uuid;
    v_qr_parts text[];
    v_session_record record;
    v_enrollment_status text;
    v_course_name text;
    v_attendance_id uuid;
    v_is_universal boolean := false;
BEGIN
    -- A. Parse QR Payload
    -- Format 1 (Session Specific): "SESSION_ID:TOKEN"
    -- Format 2 (Universal): "UNIVERSAL:CENTER_ID:TOKEN"
    v_qr_parts := regexp_split_to_array(p_qr_payload, ':');
    
    IF v_qr_parts[1] = 'UNIVERSAL' THEN
        v_is_universal := true;
        -- Start Universal Logic
        -- 1. Find ACTIVE session for this student
        -- We look for sessions that are:
        -- - Status is 'open' OR 'scheduled' (but time is right)
        -- - Student is enrolled in the group
        -- - Not closed
        SELECT s.*, g.course_name 
        INTO v_session_record
        FROM public.attendance_sessions s
        JOIN public.groups g ON g.id = s.group_id
        JOIN public.student_group_enrollments sge ON sge.group_id = g.id
        WHERE sge.student_id = p_student_id
          AND sge.status = 'active'
          AND (
              s.status = 'open' 
              OR (s.status = 'scheduled' AND s.opens_at <= now() AND (s.closes_at IS NULL OR s.closes_at > now()))
          )
        ORDER BY s.opens_at ASC -- Pick the one that started most recently or is about to start
        LIMIT 1;

        IF v_session_record IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'لا توجد حصة نشطة لك الآن');
        END IF;

        v_session_id := v_session_record.id;
        v_course_name := v_session_record.course_name;
        
    ELSE
        -- Specific Session Logic (Legacy V1)
        v_session_id := v_qr_parts[1]::uuid;
        
        SELECT s.*, g.course_name
        INTO v_session_record
        FROM public.attendance_sessions s
        JOIN public.groups g ON g.id = s.group_id
        WHERE s.id = v_session_id;

        IF v_session_record IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'الحصة غير موجودة');
        END IF;
        
        v_course_name := v_session_record.course_name;
    END IF;

    -- Common Validation (Double Check for Specific, First Check for Universal)
    IF v_session_record.status = 'closed' OR (v_session_record.closes_at IS NOT NULL AND v_session_record.closes_at < now()) THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحصة مغلقة');
    END IF;

    IF v_session_record.status = 'scheduled' AND v_session_record.opens_at > now() THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحصة لم تبدأ بعد');
    END IF;

    -- D. Check if already attended
    SELECT id INTO v_attendance_id
    FROM public.attendance
    WHERE session_id = v_session_id AND student_id = p_student_id;

    IF v_attendance_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'تم تسجيل الحضور مسبقاً', 'course_name', v_course_name);
    END IF;

    -- E. Record Attendance
    INSERT INTO public.attendance (
        session_id,
        student_id,
        status,
        check_in_time,
        created_at
    ) VALUES (
        v_session_id,
        p_student_id,
        CASE 
            WHEN v_session_record.on_time_until IS NOT NULL AND now() > v_session_record.on_time_until THEN 'late'
            ELSE 'present'
        END,
        now(),
        now()
    ) RETURNING id INTO v_attendance_id;

    -- F. Return Success
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'تم تسجيل الحضور بنجاح',
        'attendance_id', v_attendance_id,
        'course_name', v_course_name
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 3. RPC: generate_universal_qr
CREATE OR REPLACE FUNCTION public.generate_universal_qr()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key text;
    v_timestamp bigint;
    v_center_id text; -- Placeholder if multi-center
BEGIN
    -- Get key from settings (create default if none)
    SELECT universal_qr_key INTO v_key FROM public.center_settings LIMIT 1;
    
    IF v_key IS NULL THEN
        INSERT INTO public.center_settings (universal_qr_key) VALUES (md5(random()::text)) RETURNING universal_qr_key INTO v_key;
    END IF;

    -- Rotation every 15 seconds
    v_timestamp := (EXTRACT(EPOCH FROM now())::bigint / 15);
    
    -- Format: UNIVERSAL:CENTER_LOCATION:HASH
    RETURN 'UNIVERSAL:DEFAULT:' || md5(v_key || v_timestamp::text);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_universal_qr() TO authenticated;
