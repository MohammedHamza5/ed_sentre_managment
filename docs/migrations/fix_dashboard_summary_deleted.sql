CREATE OR REPLACE FUNCTION public.get_dashboard_summary(p_center_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  result JSON;
  today_dow TEXT;
  today_date DATE;
  current_time_val TIME;
BEGIN
  -- Database stores 'monday', 'tuesday', etc.
  -- PostgreSQL TO_CHAR(..., 'Day') returns 'Monday   ' (padded).
  today_dow := LOWER(TRIM(TO_CHAR(CURRENT_DATE, 'Day')));
  today_date := CURRENT_DATE;
  current_time_val := CURRENT_TIME;
  
  SELECT json_build_object(
    -- 1️⃣ العدادات الأساسية
    
    -- Students: Count 'accepted' enrollments. 
    -- Assuming student_enrollments determines active presence.
    'student_count', (
        SELECT COUNT(*)::int 
        FROM student_enrollments 
        WHERE center_id = p_center_id 
        AND status = 'accepted'
    ),
    
    -- Teachers: Count 'active' (excludes suspended/terminated)
    'teacher_count', (
        SELECT COUNT(*)::int 
        FROM teacher_enrollments 
        WHERE center_id = p_center_id 
        AND employment_status = 'active'
    ),
    
    -- Courses: Count non-deleted courses
    'course_count', (
        SELECT COUNT(*)::int 
        FROM courses 
        WHERE center_id = p_center_id
        AND deleted_at IS NULL
    ),
    
    -- Groups: Count 'active' AND non-deleted groups
    'group_count', (
        SELECT COUNT(*)::int 
        FROM groups 
        WHERE center_id = p_center_id 
        AND status = 'active'
        AND deleted_at IS NULL
    ),
    
    'active_students', (
      SELECT COUNT(*)::int FROM student_enrollments 
      WHERE center_id = p_center_id AND status = 'active'
    ),
    
    -- 2️⃣ إحصائيات الجلسات
    'today_sessions_count', (
      SELECT COUNT(*)::int FROM schedules 
      WHERE center_id = p_center_id 
      AND day_of_week = today_dow
      AND status != 'cancelled' 
      AND status != 'archived'
    ),
    'completed_sessions', (
      SELECT COUNT(*)::int FROM schedules 
      WHERE center_id = p_center_id 
      AND day_of_week = today_dow 
      AND status = 'completed'
    ),
    
    -- 3️⃣ الإيرادات
    'today_revenue', COALESCE((
      SELECT SUM(amount) FROM payments 
      WHERE center_id = p_center_id 
      AND created_at::date = today_date
    ), 0),
    'today_revenue_change', 0, -- (Optional: Calculate change vs yesterday)
    
    -- 4️⃣ Next Session Data
    'next_session_time', (
      SELECT start_time FROM schedules
      WHERE center_id = p_center_id 
        AND day_of_week = today_dow 
        AND status != 'completed'
        AND status != 'cancelled'
        AND start_time::time > current_time_val
      ORDER BY start_time ASC LIMIT 1
    ),
    'next_session_name', (
      SELECT 
        COALESCE(g.group_name, c.name) 
      FROM schedules s
      LEFT JOIN groups g ON s.group_id = g.id
      LEFT JOIN courses c ON s.course_id = c.id
      WHERE s.center_id = p_center_id 
        AND s.day_of_week = today_dow 
        AND s.status != 'completed'
        AND s.status != 'cancelled'
        AND s.start_time::time > current_time_val
      ORDER BY s.start_time ASC LIMIT 1
    ),

    -- 🔟 مخطط الإيرادات الشهري (آخر 6 شهور)
    'monthly_revenue', (
      SELECT COALESCE(json_agg(json_build_object(
        'month', TO_CHAR(month_date, 'Month'),
        'month_num', EXTRACT(MONTH FROM month_date),
        'revenue', COALESCE(revenue, 0)
      )), '[]'::json)
      FROM (
        SELECT 
          DATE_TRUNC('month', dates.payment_date)::date as month_date,
          SUM(amount) as revenue
        FROM (
          SELECT generate_series(DATE_TRUNC('month', today_date) - INTERVAL '5 months', DATE_TRUNC('month', today_date), '1 month')::date as payment_date
        ) dates
        LEFT JOIN payments p ON DATE_TRUNC('month', p.created_at) = dates.payment_date AND p.center_id = p_center_id
        GROUP BY month_date
        ORDER BY month_date DESC
      ) sub
    ),

    -- 1️⃣1️⃣ مخطط الحضور الأسبوعي
    'weekly_attendance_chart', (
       SELECT COALESCE(json_agg(json_build_object(
         'date', day_date,
         'present', COALESCE(present_count, 0),
         'absent', COALESCE(absent_count, 0)
       )), '[]'::json)
       FROM (
         SELECT 
           series_date::date as day_date,
           COUNT(*) FILTER (WHERE status = 'present') as present_count,
           COUNT(*) FILTER (WHERE status = 'absent') as absent_count
         FROM generate_series(today_date - INTERVAL '6 days', today_date - INTERVAL '1 day', '1 day') as series_date
         LEFT JOIN attendance a ON DATE(a.date) = series_date AND a.center_id = p_center_id
         GROUP BY series_date
         ORDER BY series_date DESC
       ) sub
    ),

    -- 🧠 GENIUS: Financial Intelligence Integration 🧠
    'center_pulse', get_center_pulse(p_center_id),
    'financial_forecast', get_financial_forecast(p_center_id)

  ) INTO result;
  
  RETURN result;
END;
$function$
