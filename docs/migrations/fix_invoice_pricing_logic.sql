CREATE OR REPLACE FUNCTION public.get_or_create_student_invoice(
    p_student_id uuid, 
    p_center_id uuid, 
    p_month integer, 
    p_year integer
)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_invoice_id UUID;
    v_student_name TEXT;
    v_total_amount DECIMAL(10,2) := 0;
    v_paid_amount DECIMAL(10,2) := 0;
    v_enrollment RECORD;
    v_item_amount DECIMAL(10,2);
    v_monthly_price DECIMAL(10,2);
    v_session_price DECIMAL(10,2);
    v_sessions_count INTEGER;
    v_items_arr JSONB := '[]'::jsonb;
    v_existing_invoice RECORD;
    v_billing_type TEXT;
    v_has_payments BOOLEAN;
BEGIN
    -- 1. Check if invoice exists
    SELECT * INTO v_existing_invoice
    FROM student_invoices
    WHERE student_id = p_student_id 
      AND center_id = p_center_id 
      AND month = p_month 
      AND year = p_year;

    -- Return existing if found (sync paid amount)
    IF v_existing_invoice.id IS NOT NULL THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_paid_amount
        FROM public.payments
        WHERE student_id = p_student_id
          AND center_id = p_center_id
          AND month_year = (p_month || '-' || p_year);
          
        IF v_paid_amount != v_existing_invoice.paid_amount THEN
            UPDATE student_invoices SET paid_amount = v_paid_amount WHERE id = v_existing_invoice.id;
            v_existing_invoice.paid_amount := v_paid_amount;
        END IF;

        SELECT full_name INTO v_student_name FROM public.students WHERE id = p_student_id;

        RETURN json_build_object(
            'invoice_id', v_existing_invoice.id,
            'student_id', p_student_id,
            'student_name', v_student_name,
            'center_id', p_center_id,
            'month', p_month,
            'year', p_year,
            'total_amount', v_existing_invoice.total_amount,
            'paid_amount', v_existing_invoice.paid_amount,
            'remaining', v_existing_invoice.total_amount - v_existing_invoice.paid_amount,
            'status', v_existing_invoice.status,
            'items', '[]'::jsonb
        );
    END IF;

    -- 3. If NOT exists, Calculate & Insert
    SELECT full_name INTO v_student_name FROM public.students WHERE id = p_student_id;
    
    FOR v_enrollment IN
        SELECT 
            sge.group_id,
            g.group_name,
            c.name as course_name,
            g.monthly_fee -- Fallback fee from group
        FROM public.student_group_enrollments sge
        JOIN public.groups g ON g.id = sge.group_id
        LEFT JOIN public.courses c ON c.id = g.course_id
        WHERE sge.student_id = p_student_id
          AND sge.status = 'active'
          AND g.center_id = p_center_id
    LOOP
        -- KEY FIX: Lookup price by subject_name since subject_id is often null
        -- Also priority: Course Price > Group Fee > 0
        
        v_monthly_price := 0;
        
        -- Try finding price in course_prices
        SELECT monthly_price INTO v_monthly_price
        FROM public.course_prices
        WHERE center_id = p_center_id 
          AND subject_name = v_enrollment.course_name
          AND is_active = true
        LIMIT 1;
        
        -- Fallback to group fee if no specific price found, or price is null
        v_monthly_price := COALESCE(v_monthly_price, v_enrollment.monthly_fee, 0);
        
        v_item_amount := v_monthly_price;
        v_total_amount := v_total_amount + v_item_amount;
        
        v_items_arr := v_items_arr || jsonb_build_object(
            'group_name', v_enrollment.group_name,
            'course_name', v_enrollment.course_name,
            'amount', v_item_amount
        );
    END LOOP;
    
    -- Insert new invoice
    INSERT INTO student_invoices (
        center_id, student_id, month, year, total_amount, paid_amount, status, created_at, updated_at
    ) VALUES (
        p_center_id, p_student_id, p_month, p_year, v_total_amount, 0, 'pending', NOW(), NOW()
    ) RETURNING id INTO v_invoice_id;

    RETURN json_build_object(
        'invoice_id', v_invoice_id,
        'student_id', p_student_id,
        'student_name', v_student_name,
        'center_id', p_center_id,
        'month', p_month,
        'year', p_year,
        'total_amount', v_total_amount,
        'paid_amount', 0,
        'remaining', v_total_amount,
        'status', 'pending',
        'items', v_items_arr
    );
END;
$function$
