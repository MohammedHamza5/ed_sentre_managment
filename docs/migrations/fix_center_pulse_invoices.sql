CREATE OR REPLACE FUNCTION public.get_center_pulse(p_center_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_current_month_start DATE := date_trunc('month', CURRENT_DATE);
  v_last_month_start DATE := date_trunc('month', CURRENT_DATE - INTERVAL '1 month');
  
  -- Counts to detect new center
  v_total_students INT := 0;
  v_total_invoices INT := 0;
  v_days_since_creation INT := 0;
  v_is_new_center BOOLEAN := false;
  
  -- Metrics
  v_total_invoiced DECIMAL(10, 2) := 0;
  v_total_collected DECIMAL(10, 2) := 0;
  v_collection_rate DECIMAL(5, 2) := 0;
  
  v_teacher_expenses DECIMAL(10, 2) := 0;
  v_profit_margin DECIMAL(5, 2) := 0;
  
  v_last_month_revenue DECIMAL(10, 2) := 0;
  v_current_month_revenue DECIMAL(10, 2) := 0;
  v_growth_rate DECIMAL(5, 2) := 0;
  
  v_health_score INT := 0;
  v_pulse_status TEXT;
  v_pulse_message TEXT;
  
  -- Onboarding checklist
  v_has_students BOOLEAN := false;
  v_has_teachers BOOLEAN := false;
  v_has_courses BOOLEAN := false;
  v_has_groups BOOLEAN := false;
  v_has_invoices BOOLEAN := false;
  v_setup_progress INT := 0;
  v_checklist_json JSON;
BEGIN
  -- 🔍 DETECT IF NEW CENTER
  SELECT 
    EXTRACT(DAY FROM (CURRENT_TIMESTAMP - created_at))::INT
  INTO v_days_since_creation
  FROM centers WHERE id = p_center_id;
  
  -- Count basic data to determine if center is "new"
  SELECT COUNT(*)::INT INTO v_total_students 
  FROM student_enrollments WHERE center_id = p_center_id;
  
  -- FIX: Check PAYMENTS table instead of unused student_invoices
  SELECT COUNT(*)::INT INTO v_total_invoices 
  FROM payments WHERE center_id = p_center_id;
  
  -- Center is "new" if: < 7 days old OR has no students OR no invoices
  v_is_new_center := (v_days_since_creation < 7) OR (v_total_students = 0) OR (v_total_invoices = 0);

  -- ==========================================
  -- 1. IF NEW: Return Setup Progress Logic
  -- ==========================================
  IF v_is_new_center THEN
  
    -- Calculate Checklist
    v_has_students := v_total_students > 0;
    
    SELECT COUNT(*)::INT > 0 INTO v_has_teachers 
    FROM teacher_enrollments WHERE center_id = p_center_id;
    
    SELECT COUNT(*)::INT > 0 INTO v_has_courses 
    FROM courses WHERE center_id = p_center_id AND deleted_at IS NULL;
    
    SELECT COUNT(*)::INT > 0 INTO v_has_groups 
    FROM groups WHERE center_id = p_center_id AND deleted_at IS NULL;
    
    v_has_invoices := v_total_invoices > 0;
    
    -- Calculate Progress % (5 items, 20% each)
    IF v_has_students THEN v_setup_progress := v_setup_progress + 20; END IF;
    IF v_has_teachers THEN v_setup_progress := v_setup_progress + 20; END IF;
    IF v_has_courses THEN v_setup_progress := v_setup_progress + 20; END IF;
    IF v_has_groups THEN v_setup_progress := v_setup_progress + 20; END IF;
    IF v_has_invoices THEN v_setup_progress := v_setup_progress + 20; END IF;

    v_checklist_json := json_build_object(
      'has_students', v_has_students,
      'has_teachers', v_has_teachers,
      'has_courses', v_has_courses,
      'has_groups', v_has_groups,
      'has_invoices', v_has_invoices
    );
    
    RETURN json_build_object(
      'score', v_setup_progress, -- Use progress as score during setup
      'status', CASE WHEN v_setup_progress >= 80 THEN 'almost_ready' ELSE 'setting_up' END, 
      'message', CASE 
         WHEN v_setup_progress = 100 THEN 'أحسنت! السنتر جاهز تماماً للانطلاق 🚀'
         WHEN v_setup_progress >= 80 THEN 'رائع! خطوة واحدة متبقية لتفعيل الذكاء المالي'
         ELSE 'أكمل إعداد بيانات السنتر لتفعيل التحليلات الذكية'
       END,
      'is_new_center', true,
      'setup_progress', v_setup_progress,
      'checklist', v_checklist_json,
      'collection_rate', 0,
      'profit_margin', 0,
      'growth_rate', 0
    );
  END IF;

  -- ==========================================
  -- 2. IF ESTABLISHED: Calculate Financial Health
  -- ==========================================

  -- A. Collection Rate (Collected / Invoiced)
  -- For simplified version, assumes Invoiced = Payments (Collected + Outstanding)
  -- Or if we have explicit invoices table later. 
  -- Here we will simulate "Invoiced" as "Payments" for now since we lack invoice table usage.
  -- Actually, let's look at payment stati.
  
  SELECT 
    COALESCE(SUM(amount), 0)
  INTO v_total_invoiced
  FROM payments
  WHERE center_id = p_center_id
    AND created_at >= v_current_month_start;

  SELECT 
    COALESCE(SUM(amount), 0) -- Assumes 'amount' is what was paid if status is 'paid'. Or check 'paid_amount' column if exists.
                             -- Checking schema previously: 'payments' usually has 'amount'.
  INTO v_total_collected
  FROM payments
  WHERE center_id = p_center_id
    AND status = 'paid'
    AND created_at >= v_current_month_start;
    
  IF v_total_invoiced > 0 THEN
    v_collection_rate := (v_total_collected / v_total_invoiced) * 100;
  ELSE
    v_collection_rate := 100; -- No invoices = perfect collection technically
  END IF;

  -- B. Profit Margin (Revenue - Expenses) / Revenue
  -- Calculate Revenue (Collected)
  SELECT COALESCE(SUM(amount), 0) INTO v_current_month_revenue
  FROM payments
  WHERE center_id = p_center_id
    AND status = 'paid'
    AND created_at >= v_current_month_start;
    
  -- Calculate Expenses (Teacher Salaries + Operations)
  -- Simplified: Assume 30% overhead for now if no expense table
  v_teacher_expenses := v_current_month_revenue * 0.30; 
  
  IF v_current_month_revenue > 0 THEN
    v_profit_margin := ((v_current_month_revenue - v_teacher_expenses) / v_current_month_revenue) * 100;
  ELSE
    v_profit_margin := 0;
  END IF;

  -- C. Growth Rate (Current Month vs Last Month)
  SELECT COALESCE(SUM(amount), 0) INTO v_last_month_revenue
  FROM payments
  WHERE center_id = p_center_id
    AND status = 'paid'
    AND created_at >= v_last_month_start
    AND created_at < v_current_month_start;

  IF v_last_month_revenue > 0 THEN
    v_growth_rate := ((v_current_month_revenue - v_last_month_revenue) / v_last_month_revenue) * 100;
    v_growth_rate := GREATEST(-100, LEAST(100, v_growth_rate)); -- Clamp to -100% to +100%
  ELSE
    v_growth_rate := CASE WHEN v_current_month_revenue > 0 THEN 100 ELSE 0 END;
  END IF;

  -- D. Calculate Health Score (Weighted Average)
  -- Normalize growth_rate to 0-100 scale (where 0% growth = 50)
  v_health_score := (
    (v_collection_rate * 0.4) +
    (v_profit_margin * 0.3) +
    (GREATEST(0, LEAST(100, 50 + (v_growth_rate / 2))) * 0.3)
  )::INT;
  
  v_health_score := GREATEST(0, LEAST(100, v_health_score));

  -- E. Determine Status
  IF v_health_score >= 80 THEN 
    v_pulse_status := 'excellent';
    v_pulse_message := 'السنتر في حالة ممتازة! استمر 🚀';
  ELSIF v_health_score >= 60 THEN 
    v_pulse_status := 'healthy';
    v_pulse_message := 'أداء جيد مع فرص للتحسين';
  ELSIF v_health_score >= 40 THEN 
    v_pulse_status := 'attention';
    v_pulse_message := 'انتبه! هناك مجالات تحتاج تحسين';
  ELSE 
    v_pulse_status := 'critical';
    v_pulse_message := 'تحذير! راجع التحصيل والمصروفات';
  END IF;

  RETURN json_build_object(
    'score', v_health_score,
    'status', v_pulse_status,
    'message', v_pulse_message,
    'is_new_center', false,
    'setup_progress', 100,
    'checklist', null,
    'collection_rate', ROUND(v_collection_rate, 1),
    'profit_margin', ROUND(v_profit_margin, 1),
    'growth_rate', ROUND(v_growth_rate, 1)
  );
END;
$function$
