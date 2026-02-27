CREATE OR REPLACE FUNCTION public.get_dashboard_summary(p_center_id uuid) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
  result JSON;
  today_dow TEXT;
  today_date DATE;
BEGIN
  -- FIX: Correct Day of Week mapping (Text based)
  -- Database stores 'monday', 'tuesday', etc.
  -- PostgreSQL TO_CHAR(..., 'Day') returns 'Monday   ' (padded).
  today_dow := LOWER(TRIM(TO_CHAR(CURRENT_DATE, 'Day')));
  today_date := CURRENT_DATE;
  
  SELECT json_build_object(
    -- 1️⃣ العدادات الأساسية
    'student_count', (SELECT COUNT(*)::int FROM student_enrollments WHERE center_id = p_center_id),
    'teacher_count', (SELECT COUNT(*)::int FROM teacher_enrollments WHERE center_id = p_center_id AND employment_status = 'active'),
    'course_count', (SELECT COUNT(*)::int FROM courses WHERE center_id = p_center_id),
    'group_count', (SELECT COUNT(*)::int FROM groups WHERE center_id = p_center_id AND is_active = true),
    
    'active_students', (
      SELECT COUNT(*)::int FROM student_enrollments 
      WHERE center_id = p_center_id AND status = 'active'
    ),
    
    -- 2️⃣ إحصائيات الجلسات
    'today_sessions_count', (
      SELECT COUNT(*)::int FROM schedules 
      WHERE center_id = p_center_id AND day_of_week = today_dow
    ),
    'completed_sessions', (
      SELECT COUNT(*)::int FROM schedules 
      WHERE center_id = p_center_id AND day_of_week = today_dow AND status = 'completed'
    ),
    
    -- 3️⃣ الإيرادات
    'today_revenue', COALESCE((
      SELECT SUM(amount)::numeric FROM payments 
      WHERE center_id = p_center_id AND DATE(created_at) = today_date
    ), 0),
    'monthly_revenue_total', COALESCE((
      SELECT SUM(amount)::numeric FROM payments 
      WHERE center_id = p_center_id 
        AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM today_date)
        AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM today_date)
    ), 0),
    
    -- 4️⃣ الحضور
    'attendance_rate', COALESCE((
      SELECT 
        CASE WHEN COUNT(*) > 0 
          THEN (COUNT(*) FILTER (WHERE status = 'present')::numeric / COUNT(*)::numeric * 100)
          ELSE 0 
        END
      FROM attendance 
      WHERE center_id = p_center_id 
        AND DATE(date) BETWEEN today_date - INTERVAL '7 days' AND today_date
    ), 0),
    
    -- 5️⃣ المجموعات
    'total_groups', (SELECT COUNT(*)::int FROM groups WHERE center_id = p_center_id),
    'active_groups_count', (SELECT COUNT(*)::int FROM groups WHERE center_id = p_center_id AND is_active = true),
    'full_groups', (SELECT COUNT(*)::int FROM groups WHERE center_id = p_center_id AND current_students >= max_students),

    -- 6️⃣ الجلسة القادمة
    'next_session_time', (
      SELECT start_time FROM schedules
      WHERE center_id = p_center_id AND day_of_week = today_dow AND status != 'completed'
      ORDER BY start_time LIMIT 1
    ),
    'next_session_name', (
      SELECT c.name
      FROM schedules s
      -- LEFT JOIN groups g ON g.id = s.group_id
      LEFT JOIN courses c ON c.id = s.course_id
      WHERE s.center_id = p_center_id AND s.day_of_week = today_dow AND s.status != 'completed'
      ORDER BY s.start_time LIMIT 1
    ),

    -- 7️⃣ قائمة جلسات اليوم
    'today_sessions_list', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', s.id,
        'subjectId', s.course_id,
        'subjectName', c.name,
        'teacherId', s.teacher_id,
        'teacherName', u.full_name,
        'roomId', s.classroom_id,
        'roomName', COALESCE(r.name, 'غير محدد'),
        'startTime', s.start_time,
        'endTime', s.end_time,
        'groupName', NULL,
        'status', s.status
      )), '[]'::json)
      FROM schedules s
      LEFT JOIN courses c ON c.id = s.course_id
      -- LEFT JOIN groups g ON g.id = s.group_id
      LEFT JOIN teachers t ON t.id = s.teacher_id
      LEFT JOIN users u ON u.id = t.user_id
      LEFT JOIN classrooms r ON r.id = s.classroom_id
      WHERE s.center_id = p_center_id AND s.day_of_week = today_dow
    ),

    -- 8️⃣ قائمة المتأخرات
    'overdue_invoices_list', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', inv.id,
        'studentId', s.id,
        'studentName', u.full_name,
        'amount', inv.total_amount - inv.paid_amount,
        'status', 'overdue',  
        'dueDate', inv.due_date
      )), '[]'::json)
      FROM student_invoices inv
      JOIN students s ON s.id = inv.student_id
      JOIN student_enrollments se ON se.student_id = s.id AND se.center_id = p_center_id
      JOIN users u ON u.id = se.student_user_id
      WHERE inv.center_id = p_center_id 
        AND inv.status = 'overdue'
      LIMIT 5
    ),

    -- 9️⃣ مخطط توزيع الطلاب
    'student_distribution', (
      SELECT COALESCE(json_agg(json_build_object(
        'stage', COALESCE(NULLIF(grade_level, ''), 'غير محدد'),
        'count', count
      )), '[]'::json)
      FROM (
        SELECT grade_level, COUNT(*) as count
        FROM student_enrollments se
        WHERE se.center_id = p_center_id
        GROUP BY grade_level
      ) sub
    ),

    -- 🔟 مخطط الإيرادات الشهرية
    'monthly_revenue_chart', (
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
$$;
