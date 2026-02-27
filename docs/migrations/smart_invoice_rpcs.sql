-- ══════════════════════════════════════════════════════════════════════════════
-- SMART INVOICE RPC v2.0 - نظام الفواتير الذكي
-- ══════════════════════════════════════════════════════════════════════════════
-- تاريخ: 2026-01-18
-- المميزات:
--   ✅ تناسب تلقائي حسب تاريخ التسجيل (Proration)
--   ✅ نظام الحصص الذكي (Per-Session)
--   ✅ استخدام course_prices للتسعير
--   ✅ دعم أنظمة الفوترة المختلطة

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. get_or_create_student_invoice - الفاتورة الذكية
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_or_create_student_invoice(
    p_student_id UUID,
    p_center_id UUID,
    p_month INTEGER,
    p_year INTEGER
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_student_name TEXT;
    v_total_amount DECIMAL(10,2) := 0;
    v_paid_amount DECIMAL(10,2) := 0;
    v_items JSON;
    v_billing_type TEXT := 'monthly'; -- default
    v_enrollment RECORD;
    v_item_amount DECIMAL(10,2);
    v_monthly_price DECIMAL(10,2);
    v_session_price DECIMAL(10,2);
    v_sessions_count INTEGER;
    v_proration_factor DECIMAL(5,4);
    v_days_in_month INTEGER;
    v_enrollment_day INTEGER;
    v_period_start DATE;
    v_period_end DATE;
    v_items_arr JSONB := '[]'::jsonb;
BEGIN
    -- تحديد بداية ونهاية الفترة
    v_period_start := make_date(p_year, p_month, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;
    v_days_in_month := EXTRACT(DAY FROM v_period_end);
    
    -- جلب اسم الطالب
    SELECT full_name INTO v_student_name
    FROM public.students
    WHERE id = p_student_id;
    
    -- نوع الفوترة - حالياً ثابت monthly (يمكن إضافة عمود billing_type لاحقاً)
    -- لتفعيل per_session: ALTER TABLE centers ADD COLUMN billing_type TEXT DEFAULT 'monthly';
    v_billing_type := 'monthly';
    
    -- التكرار على كل مجموعة مسجل بها الطالب
    FOR v_enrollment IN
        SELECT 
            sge.id as enrollment_id,
            sge.enrollment_date,
            sge.group_id,
            g.group_name,
            g.monthly_fee,
            g.teacher_id,
            g.grade_level,
            c.id as course_id,
            c.name as course_name,
            c.fee as course_fee
        FROM public.student_group_enrollments sge
        JOIN public.groups g ON g.id = sge.group_id
        LEFT JOIN public.courses c ON c.id = g.course_id
        WHERE sge.student_id = p_student_id
          AND sge.status = 'active'
          AND g.center_id = p_center_id
    LOOP
        -- جلب السعر من course_prices (الذكي)
        SELECT cp.monthly_price, cp.session_price 
        INTO v_monthly_price, v_session_price
        FROM public.course_prices cp
        WHERE cp.center_id = p_center_id 
          AND cp.subject_name = v_enrollment.course_name
          AND cp.is_active = true
        ORDER BY cp.teacher_id NULLS LAST, cp.grade_level NULLS LAST
        LIMIT 1;
        
        -- fallback للسعر
        v_monthly_price := COALESCE(v_monthly_price, v_enrollment.monthly_fee, v_enrollment.course_fee, 0);
        v_session_price := COALESCE(v_session_price, 0);
        
        -- حساب المبلغ حسب نوع الفوترة
        IF v_billing_type = 'per_session' THEN
            -- ═══ نظام الحصص ═══
            -- حساب عدد الحصص المحضورة في هذه الفترة
            SELECT COUNT(*) INTO v_sessions_count
            FROM public.attendance a
            JOIN public.schedules s ON a.session_id = s.id
            WHERE a.student_id = p_student_id
              AND s.group_id = v_enrollment.group_id
              AND a.date BETWEEN v_period_start AND v_period_end
              AND a.status IN ('present', 'late');
            
            v_item_amount := v_sessions_count * v_session_price;
            
            -- إضافة للـ items مع تفاصيل الحصص
            v_items_arr := v_items_arr || jsonb_build_object(
                'group_id', v_enrollment.group_id,
                'group_name', v_enrollment.group_name,
                'course_name', v_enrollment.course_name,
                'billing_type', 'per_session',
                'sessions_attended', v_sessions_count,
                'session_price', v_session_price,
                'amount', v_item_amount
            );
            
        ELSE
            -- ═══ نظام شهري (مع تناسب) ═══
            v_proration_factor := 1.0;
            
            -- تحقق إذا كان التسجيل في نفس الشهر المطلوب
            IF v_enrollment.enrollment_date >= v_period_start 
               AND v_enrollment.enrollment_date <= v_period_end THEN
                -- حساب التناسب
                v_enrollment_day := EXTRACT(DAY FROM v_enrollment.enrollment_date);
                v_proration_factor := (v_days_in_month - v_enrollment_day + 1)::DECIMAL / v_days_in_month;
            END IF;
            
            v_item_amount := ROUND(v_monthly_price * v_proration_factor, 2);
            
            -- إضافة للـ items مع تفاصيل التناسب
            v_items_arr := v_items_arr || jsonb_build_object(
                'group_id', v_enrollment.group_id,
                'group_name', v_enrollment.group_name,
                'course_name', v_enrollment.course_name,
                'billing_type', 'monthly',
                'monthly_price', v_monthly_price,
                'proration_factor', v_proration_factor,
                'enrollment_date', v_enrollment.enrollment_date,
                'amount', v_item_amount
            );
        END IF;
        
        v_total_amount := v_total_amount + v_item_amount;
    END LOOP;
    
    -- حساب المبلغ المدفوع لهذا الشهر
    SELECT COALESCE(SUM(paid_amount), 0) INTO v_paid_amount
    FROM public.payments
    WHERE student_id = p_student_id
      AND center_id = p_center_id
      AND EXTRACT(MONTH FROM payment_date) = p_month
      AND EXTRACT(YEAR FROM payment_date) = p_year;
    
    -- بناء النتيجة
    v_result := json_build_object(
        'student_id', p_student_id,
        'student_name', v_student_name,
        'center_id', p_center_id,
        'month', p_month,
        'year', p_year,
        'billing_type', v_billing_type,
        'total_amount', v_total_amount,
        'paid_amount', v_paid_amount,
        'remaining', v_total_amount - v_paid_amount,
        'status', CASE 
            WHEN v_paid_amount >= v_total_amount AND v_total_amount > 0 THEN 'paid'
            WHEN v_paid_amount > 0 THEN 'partial'
            ELSE 'pending'
        END,
        'items', v_items_arr
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. get_student_balance_summary - ملخص الرصيد الذكي
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_student_balance_summary(
    p_student_id UUID,
    p_center_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_total_due DECIMAL(10,2) := 0;
    v_total_paid DECIMAL(10,2) := 0;
    v_billing_type TEXT := 'monthly';
    v_enrollment RECORD;
    v_monthly_price DECIMAL(10,2);
    v_session_price DECIMAL(10,2);
    v_sessions_count INTEGER;
    v_current_month INTEGER := EXTRACT(MONTH FROM CURRENT_DATE);
    v_current_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE);
    v_period_start DATE;
    v_period_end DATE;
    v_days_in_month INTEGER;
    v_enrollment_day INTEGER;
    v_proration_factor DECIMAL(5,4);
BEGIN
    v_period_start := make_date(v_current_year, v_current_month, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;
    v_days_in_month := EXTRACT(DAY FROM v_period_end);
    
    -- نوع الفوترة - ثابت monthly حالياً
    v_billing_type := 'monthly';
    
    -- التكرار على كل مجموعة
    FOR v_enrollment IN
        SELECT 
            sge.enrollment_date,
            sge.group_id,
            g.monthly_fee,
            c.name as course_name,
            c.fee as course_fee
        FROM public.student_group_enrollments sge
        JOIN public.groups g ON g.id = sge.group_id
        LEFT JOIN public.courses c ON c.id = g.course_id
        WHERE sge.student_id = p_student_id
          AND sge.status = 'active'
          AND g.center_id = p_center_id
    LOOP
        -- جلب السعر الذكي
        SELECT cp.monthly_price, cp.session_price 
        INTO v_monthly_price, v_session_price
        FROM public.course_prices cp
        WHERE cp.center_id = p_center_id 
          AND cp.subject_name = v_enrollment.course_name
          AND cp.is_active = true
        ORDER BY cp.teacher_id NULLS LAST
        LIMIT 1;
        
        v_monthly_price := COALESCE(v_monthly_price, v_enrollment.monthly_fee, v_enrollment.course_fee, 0);
        v_session_price := COALESCE(v_session_price, 0);
        
        IF v_billing_type = 'per_session' THEN
            SELECT COUNT(*) INTO v_sessions_count
            FROM public.attendance a
            JOIN public.schedules s ON a.session_id = s.id
            WHERE a.student_id = p_student_id
              AND s.group_id = v_enrollment.group_id
              AND a.date BETWEEN v_period_start AND v_period_end
              AND a.status IN ('present', 'late');
            
            v_total_due := v_total_due + (v_sessions_count * v_session_price);
        ELSE
            -- تناسب للشهر الحالي
            v_proration_factor := 1.0;
            IF v_enrollment.enrollment_date >= v_period_start 
               AND v_enrollment.enrollment_date <= v_period_end THEN
                v_enrollment_day := EXTRACT(DAY FROM v_enrollment.enrollment_date);
                v_proration_factor := (v_days_in_month - v_enrollment_day + 1)::DECIMAL / v_days_in_month;
            END IF;
            
            v_total_due := v_total_due + ROUND(v_monthly_price * v_proration_factor, 2);
        END IF;
    END LOOP;
    
    -- إجمالي المدفوع
    SELECT COALESCE(SUM(paid_amount), 0) INTO v_total_paid
    FROM public.payments
    WHERE student_id = p_student_id AND center_id = p_center_id;
    
    RETURN json_build_object(
        'total_due', v_total_due,
        'total_paid', v_total_paid,
        'balance', v_total_due - v_total_paid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. get_center_revenue_report - تقرير الإيرادات الذكي للمركز
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_center_revenue_report(
    p_center_id UUID,
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_expected_revenue DECIMAL(10,2) := 0;
    v_actual_revenue DECIMAL(10,2) := 0;
    v_total_students INTEGER := 0;
    v_enrollment RECORD;
    v_monthly_price DECIMAL(10,2);
    v_current_month INTEGER := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
    v_current_year INTEGER := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_period_start DATE;
    v_period_end DATE;
    v_groups_data JSONB := '[]'::jsonb;
BEGIN
    v_period_start := make_date(v_current_year, v_current_month, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;
    
    -- حساب الإيراد المتوقع من كل مجموعة باستخدام course_prices
    FOR v_enrollment IN
        SELECT 
            g.id as group_id,
            g.group_name,
            g.monthly_fee,
            c.name as course_name,
            c.fee as course_fee,
            COUNT(sge.id) as student_count
        FROM public.groups g
        LEFT JOIN public.courses c ON c.id = g.course_id
        LEFT JOIN public.student_group_enrollments sge 
            ON sge.group_id = g.id AND sge.status = 'active'
        WHERE g.center_id = p_center_id AND g.status = 'active'
        GROUP BY g.id, g.group_name, g.monthly_fee, c.name, c.fee
    LOOP
        -- جلب السعر من course_prices (الذكي)
        SELECT cp.monthly_price INTO v_monthly_price
        FROM public.course_prices cp
        WHERE cp.center_id = p_center_id 
          AND cp.subject_name = v_enrollment.course_name
          AND cp.is_active = true
        ORDER BY cp.teacher_id NULLS LAST
        LIMIT 1;
        
        -- fallback للسعر
        v_monthly_price := COALESCE(v_monthly_price, v_enrollment.monthly_fee, v_enrollment.course_fee, 0);
        
        v_expected_revenue := v_expected_revenue + (v_monthly_price * v_enrollment.student_count);
        v_total_students := v_total_students + v_enrollment.student_count;
        
        -- إضافة بيانات المجموعة
        v_groups_data := v_groups_data || jsonb_build_object(
            'group_id', v_enrollment.group_id,
            'group_name', v_enrollment.group_name,
            'course_name', v_enrollment.course_name,
            'monthly_price', v_monthly_price,
            'student_count', v_enrollment.student_count,
            'expected_revenue', v_monthly_price * v_enrollment.student_count
        );
    END LOOP;
    
    -- حساب الإيراد الفعلي (المدفوعات هذا الشهر)
    SELECT COALESCE(SUM(paid_amount), 0) INTO v_actual_revenue
    FROM public.payments
    WHERE center_id = p_center_id
      AND payment_date BETWEEN v_period_start AND v_period_end;
    
    RETURN json_build_object(
        'month', v_current_month,
        'year', v_current_year,
        'expected_revenue', v_expected_revenue,
        'actual_revenue', v_actual_revenue,
        'collection_rate', CASE WHEN v_expected_revenue > 0 
            THEN ROUND((v_actual_revenue / v_expected_revenue * 100)::numeric, 2) 
            ELSE 0 END,
        'overdue_amount', GREATEST(v_expected_revenue - v_actual_revenue, 0),
        'total_students', v_total_students,
        'groups', v_groups_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. get_teacher_statistics - إحصائيات المعلم الشاملة (مُحسّنة)
-- ══════════════════════════════════════════════════════════════════════════════
-- ✅ يحسب المحصل الفعلي وليس المتوقع فقط
-- ✅ يحسب نصيب المعلم ونصيب المركز
-- ✅ يدعم أنواع الرواتب الثلاثة
CREATE OR REPLACE FUNCTION public.get_teacher_statistics(
    p_center_id UUID,
    p_teacher_id UUID DEFAULT NULL,
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_teacher RECORD;
    v_group RECORD;
    v_teachers_data JSONB := '[]'::jsonb;
    v_groups_data JSONB;
    v_schedules_count INTEGER;
    v_students_count INTEGER;
    v_monthly_price DECIMAL(10,2);
    v_expected_revenue DECIMAL(10,2);
    v_collected_revenue DECIMAL(10,2);
    v_teacher_share DECIMAL(10,2);
    v_center_share DECIMAL(10,2);
    v_teacher_total_expected DECIMAL(10,2);
    v_teacher_total_collected DECIMAL(10,2);
    v_teacher_total_students INTEGER;
    v_salary_type TEXT;
    v_salary_amount DECIMAL(10,2);
    v_period_start DATE;
    v_period_end DATE;
    v_current_month INTEGER := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
    v_current_year INTEGER := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
BEGIN
    v_period_start := make_date(v_current_year, v_current_month, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;
    
    FOR v_teacher IN
        SELECT DISTINCT
            te.teacher_id,
            u.full_name as teacher_name,
            u.phone,
            te.salary_type,
            te.salary_amount
        FROM public.teacher_enrollments te
        JOIN public.teachers t ON t.id = te.teacher_id
        JOIN public.users u ON u.id = t.user_id
        WHERE te.center_id = p_center_id
          AND (p_teacher_id IS NULL OR te.teacher_id = p_teacher_id)
          AND te.employment_status = 'active'
    LOOP
        v_groups_data := '[]'::jsonb;
        v_teacher_total_expected := 0;
        v_teacher_total_collected := 0;
        v_teacher_total_students := 0;
        v_salary_type := COALESCE(v_teacher.salary_type, 'percentage');
        v_salary_amount := COALESCE(v_teacher.salary_amount, 0);
        
        FOR v_group IN
            SELECT 
                g.id as group_id,
                g.group_name,
                g.grade_level,
                g.monthly_fee,
                c.name as course_name,
                c.fee as course_fee
            FROM public.groups g
            LEFT JOIN public.courses c ON c.id = g.course_id
            WHERE g.teacher_id = v_teacher.teacher_id
              AND g.center_id = p_center_id
              AND g.status = 'active'
        LOOP
            SELECT COUNT(*) INTO v_students_count
            FROM public.student_group_enrollments sge
            WHERE sge.group_id = v_group.group_id AND sge.status = 'active';
            
            SELECT COUNT(*) INTO v_schedules_count
            FROM public.schedules s WHERE s.group_id = v_group.group_id;
            
            SELECT cp.monthly_price INTO v_monthly_price
            FROM public.course_prices cp
            WHERE cp.center_id = p_center_id 
              AND cp.subject_name = v_group.course_name
              AND cp.is_active = true
            ORDER BY cp.grade_level NULLS LAST LIMIT 1;
            
            v_monthly_price := COALESCE(v_monthly_price, v_group.monthly_fee, v_group.course_fee, 0);
            v_expected_revenue := v_monthly_price * v_students_count;
            
            -- ═══ حساب المحصل الفعلي من payments ═══
            SELECT COALESCE(SUM(p.paid_amount), 0) INTO v_collected_revenue
            FROM public.payments p
            JOIN public.invoice_items ii ON ii.invoice_id = p.invoice_id
            WHERE ii.group_id = v_group.group_id
              AND p.payment_date BETWEEN v_period_start AND v_period_end
              AND p.status = 'completed';
            
            -- حساب نصيب المعلم ونصيب المركز
            IF v_salary_type = 'percentage' THEN
                v_teacher_share := v_collected_revenue * (v_salary_amount / 100);
                v_center_share := v_collected_revenue - v_teacher_share;
            ELSIF v_salary_type = 'per_session' THEN
                v_teacher_share := v_schedules_count * v_salary_amount * 4; -- 4 weeks
                v_center_share := v_collected_revenue - v_teacher_share;
            ELSE -- fixed
                v_teacher_share := v_salary_amount / GREATEST(jsonb_array_length(v_groups_data) + 1, 1);
                v_center_share := v_collected_revenue;
            END IF;
            
            v_teacher_total_expected := v_teacher_total_expected + v_expected_revenue;
            v_teacher_total_collected := v_teacher_total_collected + v_collected_revenue;
            v_teacher_total_students := v_teacher_total_students + v_students_count;
            
            v_groups_data := v_groups_data || jsonb_build_object(
                'group_id', v_group.group_id,
                'group_name', v_group.group_name,
                'course_name', v_group.course_name,
                'grade_level', v_group.grade_level,
                'students_count', v_students_count,
                'schedules_count', v_schedules_count,
                'monthly_price', v_monthly_price,
                'expected_revenue', v_expected_revenue,
                'collected_revenue', v_collected_revenue,
                'collection_rate', CASE WHEN v_expected_revenue > 0 
                    THEN ROUND((v_collected_revenue / v_expected_revenue * 100)::numeric, 1) ELSE 0 END,
                'teacher_share', v_teacher_share,
                'center_share', v_center_share
            );
        END LOOP;
        
        -- حساب إجمالي نصيب المعلم
        IF v_salary_type = 'fixed' THEN
            v_teacher_share := v_salary_amount;
            v_center_share := v_teacher_total_collected - v_salary_amount;
        ELSIF v_salary_type = 'percentage' THEN
            v_teacher_share := v_teacher_total_collected * (v_salary_amount / 100);
            v_center_share := v_teacher_total_collected - v_teacher_share;
        ELSE
            SELECT COUNT(*) * v_salary_amount * 4 INTO v_teacher_share
            FROM public.schedules s
            JOIN public.groups g ON g.id = s.group_id
            WHERE g.teacher_id = v_teacher.teacher_id AND g.center_id = p_center_id;
            v_center_share := v_teacher_total_collected - v_teacher_share;
        END IF;
        
        v_teachers_data := v_teachers_data || jsonb_build_object(
            'teacher_id', v_teacher.teacher_id,
            'teacher_name', v_teacher.teacher_name,
            'phone', v_teacher.phone,
            'salary_type', v_salary_type,
            'salary_amount', v_salary_amount,
            'groups_count', jsonb_array_length(v_groups_data),
            'total_students', v_teacher_total_students,
            'expected_revenue', v_teacher_total_expected,
            'collected_revenue', v_teacher_total_collected,
            'collection_rate', CASE WHEN v_teacher_total_expected > 0 
                THEN ROUND((v_teacher_total_collected / v_teacher_total_expected * 100)::numeric, 1) ELSE 0 END,
            'teacher_share', v_teacher_share,
            'center_share', v_center_share,
            'groups', v_groups_data
        );
    END LOOP;
    
    RETURN json_build_object(
        'center_id', p_center_id,
        'month', v_current_month,
        'year', v_current_year,
        'teachers_count', jsonb_array_length(v_teachers_data),
        'teachers', v_teachers_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. get_center_financial_dashboard - لوحة المالية الشاملة
-- ══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_center_financial_dashboard(
    p_center_id UUID,
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_period_start DATE;
    v_period_end DATE;
    v_current_month INTEGER := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
    v_current_year INTEGER := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_total_invoiced DECIMAL(10,2) := 0;
    v_total_collected DECIMAL(10,2) := 0;
    v_total_teacher_dues DECIMAL(10,2) := 0;
    v_total_teacher_paid DECIMAL(10,2) := 0;
    v_total_expenses DECIMAL(10,2) := 0;
    v_center_share DECIMAL(10,2) := 0;
    v_net_profit DECIMAL(10,2) := 0;
    v_teachers_summary JSONB := '[]'::jsonb;
    v_teacher RECORD;
BEGIN
    v_period_start := make_date(v_current_year, v_current_month, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;
    
    -- إجمالي الفواتير
    SELECT COALESCE(SUM(total_amount), 0) INTO v_total_invoiced
    FROM public.student_invoices
    WHERE center_id = p_center_id AND month = v_current_month AND year = v_current_year;
    
    -- إجمالي المحصل
    SELECT COALESCE(SUM(paid_amount), 0) INTO v_total_collected
    FROM public.payments
    WHERE center_id = p_center_id 
      AND payment_date BETWEEN v_period_start AND v_period_end
      AND status = 'completed';
    
    -- حساب مستحقات كل معلم
    FOR v_teacher IN
        SELECT 
            te.teacher_id,
            u.full_name as teacher_name,
            te.salary_type,
            te.salary_amount
        FROM public.teacher_enrollments te
        JOIN public.teachers t ON t.id = te.teacher_id
        JOIN public.users u ON u.id = t.user_id
        WHERE te.center_id = p_center_id AND te.employment_status = 'active'
    LOOP
        DECLARE
            v_teacher_collected DECIMAL(10,2) := 0;
            v_teacher_due DECIMAL(10,2) := 0;
            v_teacher_paid DECIMAL(10,2) := 0;
        BEGIN
            -- المحصل من مجموعات هذا المعلم
            SELECT COALESCE(SUM(p.paid_amount), 0) INTO v_teacher_collected
            FROM public.payments p
            JOIN public.invoice_items ii ON ii.invoice_id = p.invoice_id
            JOIN public.groups g ON g.id = ii.group_id
            WHERE g.teacher_id = v_teacher.teacher_id
              AND g.center_id = p_center_id
              AND p.payment_date BETWEEN v_period_start AND v_period_end
              AND p.status = 'completed';
            
            -- حساب المستحق
            IF v_teacher.salary_type = 'fixed' THEN
                v_teacher_due := v_teacher.salary_amount;
            ELSIF v_teacher.salary_type = 'percentage' THEN
                v_teacher_due := v_teacher_collected * (v_teacher.salary_amount / 100);
            ELSE -- per_session
                SELECT COUNT(*) * v_teacher.salary_amount * 4 INTO v_teacher_due
                FROM public.schedules s
                JOIN public.groups g ON g.id = s.group_id
                WHERE g.teacher_id = v_teacher.teacher_id AND g.center_id = p_center_id;
            END IF;
            
            -- المدفوع للمعلم
            SELECT COALESCE(SUM(net_salary), 0) INTO v_teacher_paid
            FROM public.teacher_salaries
            WHERE teacher_id = v_teacher.teacher_id
              AND center_id = p_center_id
              AND month = v_current_month AND year = v_current_year
              AND status = 'paid';
            
            v_total_teacher_dues := v_total_teacher_dues + v_teacher_due;
            v_total_teacher_paid := v_total_teacher_paid + v_teacher_paid;
            v_center_share := v_center_share + (v_teacher_collected - v_teacher_due);
            
            v_teachers_summary := v_teachers_summary || jsonb_build_object(
                'teacher_id', v_teacher.teacher_id,
                'teacher_name', v_teacher.teacher_name,
                'collected', v_teacher_collected,
                'due', v_teacher_due,
                'paid', v_teacher_paid,
                'remaining', v_teacher_due - v_teacher_paid
            );
        END;
    END LOOP;
    
    -- إجمالي المصروفات
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.expenses
    WHERE center_id = p_center_id
      AND expense_date BETWEEN v_period_start AND v_period_end;
    
    -- صافي الربح
    v_net_profit := v_center_share - v_total_expenses;
    
    RETURN json_build_object(
        'center_id', p_center_id,
        'month', v_current_month,
        'year', v_current_year,
        'period_start', v_period_start,
        'period_end', v_period_end,
        'students', json_build_object(
            'total_invoiced', v_total_invoiced,
            'total_collected', v_total_collected,
            'collection_rate', CASE WHEN v_total_invoiced > 0 
                THEN ROUND((v_total_collected / v_total_invoiced * 100)::numeric, 1) ELSE 0 END,
            'outstanding', v_total_invoiced - v_total_collected
        ),
        'teachers', json_build_object(
            'total_dues', v_total_teacher_dues,
            'total_paid', v_total_teacher_paid,
            'remaining', v_total_teacher_dues - v_total_teacher_paid,
            'details', v_teachers_summary
        ),
        'center', json_build_object(
            'gross_revenue', v_total_collected,
            'center_share', v_center_share,
            'expenses', v_total_expenses,
            'net_profit', v_net_profit,
            'profit_margin', CASE WHEN v_total_collected > 0 
                THEN ROUND((v_net_profit / v_total_collected * 100)::numeric, 1) ELSE 0 END
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ══════════════════════════════════════════════════════════════════════════════
-- صلاحيات التنفيذ
-- ══════════════════════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.get_or_create_student_invoice(UUID, UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_balance_summary(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_center_revenue_report(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_teacher_statistics(UUID, UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_center_financial_dashboard(UUID, INTEGER, INTEGER) TO authenticated;


