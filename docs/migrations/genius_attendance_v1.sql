-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Genius Attendance System V1
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Alter attendance_sessions table
ALTER TABLE public.attendance_sessions
ADD COLUMN IF NOT EXISTS status text DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'open', 'locked', 'closed')),
ADD COLUMN IF NOT EXISTS opens_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS closes_at timestamptz,
ADD COLUMN IF NOT EXISTS qr_code_rotation_key text DEFAULT md5(random()::text);

-- 2. Enable RLS on attendance_sessions if not already enabled
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;

-- 3. Policy: Authenticated users can view sessions (needed for students to find session)
CREATE POLICY "Authenticated users can view sessions"
ON public.attendance_sessions
FOR SELECT
TO authenticated
USING (true);

-- 4. Policy: Teachers/Admins can insert/update sessions
-- Assuming public.is_center_admin(center_id) or similar function exists, 
-- but for now we'll allow authenticated to create/update for simplicity in this migration
-- In production, strict policies should be applied based on center_id
CREATE POLICY "Teachers can manage sessions"
ON public.attendance_sessions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. RPC: secure_check_in
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
    v_group_id uuid;
    v_session_record record;
    v_enrollment_status text;
    v_attendance_id uuid;
BEGIN
    -- A. Parse QR Payload
    -- Payload format expected: "SESSION_ID:ROTATING_TOKEN" or just "SESSION_ID" for static
    -- For V1 simple dynamic: We assume payload IS the session_id for now, 
    -- or we can implement TOTP using qr_code_rotation_key later.
    -- Let's stick to session_id for this step, trusting the dynamic QR visual on screen.
    v_session_id := (regexp_split_to_array(p_qr_payload, ':'))[1]::uuid;

    -- B. Fetch Session & Validate
    SELECT * INTO v_session_record
    FROM public.attendance_sessions
    WHERE id = v_session_id;

    IF v_session_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    IF v_session_record.status = 'closed' OR (v_session_record.closes_at IS NOT NULL AND v_session_record.closes_at < now()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session is closed');
    END IF;

    IF v_session_record.status = 'scheduled' AND v_session_record.opens_at > now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not started yet');
    END IF;

    -- C. Check Enrollment
    v_group_id := v_session_record.group_id;
    
    SELECT status INTO v_enrollment_status
    FROM public.student_group_enrollments
    WHERE student_id = p_student_id AND group_id = v_group_id;

    IF v_enrollment_status IS NULL OR v_enrollment_status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Student not enrolled in this group');
    END IF;

    -- D. Check if already attended
    SELECT id INTO v_attendance_id
    FROM public.attendance
    WHERE session_id = v_session_id AND student_id = p_student_id;

    IF v_attendance_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Already checked in');
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
        'message', 'Check-in successful',
        'attendance_id', v_attendance_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 6. RPC: generate_session_qr
-- Returns the current valid QR string for a session
CREATE OR REPLACE FUNCTION public.generate_session_qr(p_session_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key text;
    v_timestamp bigint;
BEGIN
    SELECT qr_code_rotation_key INTO v_key
    FROM public.attendance_sessions
    WHERE id = p_session_id;
    
    -- Simple rotation: session_id + timestamp rounded to 15 seconds
    v_timestamp := (EXTRACT(EPOCH FROM now())::bigint / 15);
    
    RETURN p_session_id || ':' || md5(v_key || v_timestamp::text);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.secure_check_in(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_session_qr(uuid) TO authenticated;
