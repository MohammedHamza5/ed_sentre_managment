-- ══════════════════════════════════════════════════════════════════════════════
-- SIMULATION: Offline & Edge Case Testing
-- ══════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
    v_student_id uuid;
    v_group_id uuid;
    v_key text;
    v_timestamp_now bigint;
    v_timestamp_old bigint;
    v_timestamp_future bigint;
    v_signature_valid text;
    v_signature_old text;
    v_signature_forged text;
    v_result jsonb;
BEGIN
    -- 0. Setup Data
    SELECT id INTO v_student_id FROM public.students LIMIT 1;
    SELECT id INTO v_group_id FROM public.groups LIMIT 1;
    SELECT universal_qr_key INTO v_key FROM public.center_settings LIMIT 1;

    -- Ensure Active Enrollment
    INSERT INTO public.student_group_enrollments (student_id, group_id, status)
    VALUES (v_student_id, v_group_id, 'active')
    ON CONFLICT (student_id, group_id) DO UPDATE SET status = 'active';

    -- Create Open Session
    INSERT INTO public.attendance_sessions (group_id, opens_at, closes_at, status)
    VALUES (v_group_id, now() - interval '10 minutes', now() + interval '50 minutes', 'open')
    ON CONFLICT DO NOTHING;

    -- 1. Test Valid Check-in (Online/Offline same logic for validity)
    v_timestamp_now := (EXTRACT(EPOCH FROM now())::bigint / 15);
    v_signature_valid := md5(v_key || v_timestamp_now::text);
    
    v_result := public.secure_check_in(
        v_student_id, 
        'UNIVERSAL:DEFAULT:' || v_timestamp_now::text || ':' || v_signature_valid
    );
    RAISE NOTICE 'Test 1 (Valid): %', v_result;

    -- 2. Test Expired QR (Old Timestamp outside Session Window?)
    -- Actually our RPC checks if session was open AT THAT TIME.
    -- So if we send a timestamp from 1 hour ago (session not open then?), it should fail.
    v_timestamp_old := (EXTRACT(EPOCH FROM (now() - interval '2 hours'))::bigint / 15);
    v_signature_old := md5(v_key || v_timestamp_old::text);

    v_result := public.secure_check_in(
        v_student_id, 
        'UNIVERSAL:DEFAULT:' || v_timestamp_old::text || ':' || v_signature_old
    );
    RAISE NOTICE 'Test 2 (Expired/No Session): %', v_result;

    -- 3. Test Forged Signature (Valid Timestamp, Wrong Signature)
    v_signature_forged := md5('WRONG_KEY' || v_timestamp_now::text);
    
    v_result := public.secure_check_in(
        v_student_id, 
        'UNIVERSAL:DEFAULT:' || v_timestamp_now::text || ':' || v_signature_forged
    );
    RAISE NOTICE 'Test 3 (Forged): %', v_result;

END $$;
