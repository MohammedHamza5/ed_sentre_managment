-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Genius Attendance System V3 (Offline Support)
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. UPDATE RPC: generate_universal_qr (New Format)
-- Old Format: UNIVERSAL:DEFAULT:HASH
-- New Format: UNIVERSAL:DEFAULT:TIMESTAMP:SIGNATURE
CREATE OR REPLACE FUNCTION public.generate_universal_qr()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key text;
    v_timestamp bigint;
    v_signature text;
BEGIN
    SELECT universal_qr_key INTO v_key FROM public.center_settings LIMIT 1;
    
    -- Rotation every 15 seconds
    v_timestamp := (EXTRACT(EPOCH FROM now())::bigint / 15);
    
    -- Signature = MD5(KEY + TIMESTAMP)
    v_signature := md5(v_key || v_timestamp::text);
    
    -- Return components needed for offline verification
    -- We expose TIMESTAMP so the check-in RPC knows WHICH 15-second window this was.
    RETURN 'UNIVERSAL:DEFAULT:' || v_timestamp::text || ':' || v_signature;
END;
$$;

-- 2. UPDATE RPC: secure_check_in (Verifiable logic)
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
    v_qr_parts text[];
    v_session_record record;
    v_enrollment_status text;
    v_course_name text;
    v_attendance_id uuid;
    v_is_universal boolean := false;
    
    -- Verification vars
    v_key text;
    v_timestamp bigint;
    v_provided_signature text;
    v_calculated_signature text;
    v_qr_time timestamptz;
BEGIN
    -- A. Parse QR Payload
    v_qr_parts := regexp_split_to_array(p_qr_payload, ':');
    
    IF v_qr_parts[1] = 'UNIVERSAL' THEN
        v_is_universal := true;
        
        -- Start Universal Logic 🛡️
        
        -- v_qr_parts[3] is TIMESTAMP (15s epoch)
        -- v_qr_parts[4] is SIGNATURE
        
        IF array_length(v_qr_parts, 1) < 4 THEN
             RETURN jsonb_build_object('success', false, 'message', 'Invalid QR Format');
        END IF;

        v_timestamp := v_qr_parts[3]::bigint;
        v_provided_signature := v_qr_parts[4];
        
        -- 1. Verify Signature
        SELECT universal_qr_key INTO v_key FROM public.center_settings LIMIT 1;
        v_calculated_signature := md5(v_key || v_timestamp::text);
        
        IF v_provided_signature != v_calculated_signature THEN
             RETURN jsonb_build_object('success', false, 'message', 'Invalid QR Signature (Fake/Forged)');
        END IF;
        
        -- 2. Calculate Real Time from Timestamp
        -- Timestamp is (Epoch / 15)
        v_qr_time := to_timestamp(v_timestamp * 15);
        
        -- 3. Find Session ACTIVE AT THAT TIME
        -- Instead of checking against now(), we check against v_qr_time
        -- This allows for "Offline Check-in" where the scan happened in the past
        SELECT s.*, c.name as course_name 
        INTO v_session_record
        FROM public.attendance_sessions s
        JOIN public.groups g ON g.id = s.group_id
        JOIN public.courses c ON c.id = g.course_id
        JOIN public.student_group_enrollments sge ON sge.group_id = g.id
        WHERE sge.student_id = p_student_id
          AND sge.status = 'active'
          AND (
              s.status = 'open' 
              OR s.status = 'active'
              OR (
                  s.status = 'scheduled' 
                  AND s.opens_at <= v_qr_time 
                  AND (s.closes_at IS NULL OR s.closes_at > v_qr_time)
              )
          )
        ORDER BY s.opens_at DESC
        LIMIT 1;

        IF v_session_record IS NULL THEN
            -- Debug info: help user understand why
            RETURN jsonb_build_object('success', false, 'message', 'لا توجد حصة نشطة في وقت المسح (' || v_qr_time::text || ')');
        END IF;

        v_session_id := v_session_record.id;
        v_course_name := v_session_record.course_name;
        
    ELSE
        -- Specific Session Logic (Legacy) behavior remains checking against now() for security unless we update it too
        -- For now keeping as is for backward compat
        v_session_id := v_qr_parts[1]::uuid;
        SELECT s.*, g.id as group_id, c.name as course_name 
        INTO v_session_record
        FROM public.attendance_sessions s 
        JOIN public.groups g ON g.id = s.group_id 
        JOIN public.courses c ON c.id = g.course_id
        WHERE s.id = v_session_id;

        IF v_session_record IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'الحصة غير موجودة'); END IF;
        SELECT status INTO v_enrollment_status FROM public.student_group_enrollments WHERE student_id = p_student_id AND group_id = v_session_record.group_id;
        IF v_enrollment_status IS NULL OR v_enrollment_status != 'active' THEN RETURN jsonb_build_object('success', false, 'message', 'Student not enrolled'); END IF;
        
        v_course_name := v_session_record.course_name;
        
        -- Validate Time (Strict processing time check for legacy)
        IF v_session_record.status = 'closed' OR (v_session_record.closes_at IS NOT NULL AND v_session_record.closes_at < now()) THEN RETURN jsonb_build_object('success', false, 'message', 'الحصة مغلقة'); END IF;
        IF v_session_record.status = 'scheduled' AND v_session_record.opens_at > now() THEN RETURN jsonb_build_object('success', false, 'message', 'الحصة لم تبدأ بعد'); END IF;
    END IF;

    -- Common: Check duplicate
    SELECT id INTO v_attendance_id
    FROM public.attendance
    WHERE session_id = v_session_id AND student_id = p_student_id;

    IF v_attendance_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'تم تسجيل الحضور مسبقاً', 'course_name', v_course_name);
    END IF;

    -- Record Attendance (Backdated if needed?)
    -- Ideally we record check_in_time as the QR time, but created_at as now
    INSERT INTO public.attendance (
        session_id,
        student_id,
        center_id,
        status,
        check_in_time,
        created_at
    ) VALUES (
        v_session_id,
        p_student_id,
        v_session_record.center_id,
        'present',
        COALESCE(v_qr_time, now()), -- Use QR time as check-in time
        now()
    ) RETURNING id INTO v_attendance_id;

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
