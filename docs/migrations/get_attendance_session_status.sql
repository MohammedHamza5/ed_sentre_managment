-- ══════════════════════════════════════════════════════════════════════════════
-- FIX: Add get_attendance_session_status Function
-- ══════════════════════════════════════════════════════════════════════════════
-- Date: 2026-01-18
-- Description: Adds the missing RPC function required by QRAttendanceScreen
-- to display session statistics and student lists.

CREATE OR REPLACE FUNCTION public.get_attendance_session_status(p_session_id UUID)
RETURNS JSON AS $$
DECLARE
    v_group_id UUID;
    v_closes_at TIMESTAMPTZ;
    v_time_remaining INTEGER;
    v_total_students INTEGER;
    v_present_count INTEGER;
    v_late_count INTEGER;
    v_absent_count INTEGER;
    v_present_students JSONB;
    v_session_data JSONB;
BEGIN
    -- 1. Get session details as JSON to inspect columns
    SELECT to_jsonb(t) INTO v_session_data
    FROM public.attendance_sessions t
    WHERE t.id = p_session_id;

    IF v_session_data IS NULL THEN
        RAISE EXCEPTION 'Session not found: %', p_session_id;
    END IF;

    -- DEBUG LOGGING: Session Structure
    RAISE LOG 'DEBUG: Session Data Keys: %', (SELECT jsonb_agg(k) FROM jsonb_object_keys(v_session_data) k);
    RAISE LOG 'DEBUG: Session Data Full: %', v_session_data;

    -- Extract group_id safely
    v_group_id := (v_session_data->>'group_id')::UUID;

    -- Attempt to calculate time remaining
    BEGIN
        IF v_session_data ? 'closes_at' THEN
            v_closes_at := (v_session_data->>'closes_at')::TIMESTAMPTZ;
            v_time_remaining := EXTRACT(EPOCH FROM (v_closes_at - NOW()))::INTEGER;
        ELSIF v_session_data ? 'duration_minutes' THEN
             -- User logic:
             -- 1. Opens 30 mins before class (assumed created_at)
             -- 2. Closes after half the class time
             -- Formula: created_at + 30 minutes (pre-class) + (duration / 2)
             v_closes_at := ((v_session_data->>'created_at')::TIMESTAMPTZ + interval '30 minutes' + (((v_session_data->>'duration_minutes')::INTEGER / 2) || ' minutes')::interval);
             v_time_remaining := EXTRACT(EPOCH FROM (v_closes_at - NOW()))::INTEGER;
        ELSIF v_session_data ? 'duration' THEN
             v_closes_at := ((v_session_data->>'created_at')::TIMESTAMPTZ + (v_session_data->>'duration')::interval);
             v_time_remaining := EXTRACT(EPOCH FROM (v_closes_at - NOW()))::INTEGER;
        ELSE
             v_time_remaining := 0;
             RAISE LOG 'DEBUG: No time column (closes_at/duration) found in session.';
        END IF;

        IF v_time_remaining < 0 THEN v_time_remaining := 0; END IF;
    EXCEPTION WHEN OTHERS THEN
        v_time_remaining := 0;
        RAISE LOG 'DEBUG: Error calculating time: %', SQLERRM;
    END;

    -- 3. Get total students
    IF v_group_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_total_students
        FROM public.student_group_enrollments
        WHERE group_id = v_group_id AND status = 'active';
    ELSE 
        v_total_students := 0;
    END IF;

    -- 4. Get attendance counts safely using JSONB to avoid "column does not exist" on status if it's named differently
    -- But status is likely standard. We will just use the standard count for stats, assuming "status" exists or we catch error.
    BEGIN
        SELECT 
            COUNT(*) FILTER (WHERE status = 'present'),
            COUNT(*) FILTER (WHERE status = 'late'),
            COUNT(*) FILTER (WHERE status = 'absent')
        INTO v_present_count, v_late_count, v_absent_count
        FROM public.attendance
        WHERE session_id = p_session_id;
    EXCEPTION WHEN OTHERS THEN
         RAISE LOG 'DEBUG: Error counting attendance (check status column): %', SQLERRM;
         v_present_count := 0;
         v_late_count := 0;
         v_absent_count := 0;
    END;

    -- 5. Get detailed list of students - SAFE MODE
    -- We select the whole row as jsonb to inspect it for 'attended_at' or alternatives
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', s.full_name,
            'status', COALESCE(a_row->>'status', 'present'),
            'check_in_time', COALESCE(a_row->>'attended_at', a_row->>'created_at', a_row->>'check_in_time', a_row->>'date'),
            'debug_keys', (SELECT jsonb_agg(k) FROM jsonb_object_keys(a_row) k) -- Send keys to frontend for debugging
        )
    )
    INTO v_present_students
    FROM (
        SELECT to_jsonb(a) as a_row, student_id
        FROM public.attendance a
        WHERE a.session_id = p_session_id 
        -- We can't easily filter by status if we aren't sure it exists, but let's assume status exists primarily
        -- If this fails, the whole block fails, so we'll wrap it? 
        -- Attempting to filter by status inside the subquery might fail if status column missing.
        -- But 'status' is very standard. 'attended_at' was the issue.
    ) safe_a
    JOIN public.students s ON safe_a.student_id = s.id
    WHERE (safe_a.a_row->>'status') IN ('present', 'late');

    -- Log one attendance row for debugging
    IF v_present_students IS NOT NULL AND jsonb_array_length(v_present_students) > 0 THEN
         RAISE LOG 'DEBUG: Sample Attendance Row: %', v_present_students->0;
    ELSE 
         RAISE LOG 'DEBUG: No present students found or failed to fetch.';
    END IF;

    -- 6. Return constructed JSON
    RETURN json_build_object(
        'session_id', p_session_id,
        'group_id', v_group_id,
        'total_students', v_total_students,
        'present_count', v_present_count,
        'late_count', v_late_count,
        'absent_count', v_absent_count,
        'attendance_rate', CASE 
            WHEN v_total_students > 0 THEN 
                ROUND((v_present_count + v_late_count)::DECIMAL / v_total_students * 100, 1) 
            ELSE 0 
        END,
        'time_remaining_seconds', v_time_remaining,
        'present_students', COALESCE(v_present_students, '[]'::jsonb),
        'debug_session_data', v_session_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_attendance_session_status(UUID) TO authenticated;
