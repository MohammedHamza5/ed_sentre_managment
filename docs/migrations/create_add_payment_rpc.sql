CREATE OR REPLACE FUNCTION public.add_payment_to_invoice(
    p_invoice_id uuid,
    p_amount numeric,
    p_method text,
    p_notes text,
    p_center_id uuid
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_student_id UUID;
  v_month INT;
  v_year INT;
  v_total_amount NUMERIC;
  v_current_paid NUMERIC;
  v_new_paid NUMERIC;
  v_new_status TEXT;
  v_month_year TEXT;
BEGIN
  -- 1. Get Invoice Details
  SELECT student_id, month, year, total_amount, COALESCE(paid_amount, 0)
  INTO v_student_id, v_month, v_year, v_total_amount, v_current_paid
  FROM student_invoices
  WHERE id = p_invoice_id AND center_id = p_center_id;
  
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Invoice not found';
  END IF;

  v_month_year := v_month || '-' || v_year;

  -- 2. Insert Payment Record
  INSERT INTO payments (
    center_id,
    student_id,
    amount,
    paid_amount,
    payment_method,
    payment_date,
    status,
    month_year,
    notes,
    payment_type,
    created_at,
    updated_at
  ) VALUES (
    p_center_id,
    v_student_id,
    p_amount,
    p_amount, -- Full amount is paid relative to this transaction
    p_method,
    CURRENT_DATE,
    'paid',
    v_month_year,
    COALESCE(p_notes, 'سداد فاتورة ' || v_month || '/' || v_year),
    'tuition', -- Default type
    NOW(),
    NOW()
  );

  -- 3. Update Invoice Status
  v_new_paid := v_current_paid + p_amount;
  
  IF v_new_paid >= v_total_amount - 0.5 THEN -- Tolerance for float issues
    v_new_status := 'paid';
  ELSE
    v_new_status := 'partial';
  END IF;

  UPDATE student_invoices
  SET 
    paid_amount = v_new_paid,
    status = v_new_status,
    paid_date = CASE WHEN v_new_status = 'paid' THEN NOW() ELSE paid_date END,
    updated_at = NOW()
  WHERE id = p_invoice_id;

END;
$function$
