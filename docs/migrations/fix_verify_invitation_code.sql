-- =============================================
-- Migration: Fix verify_invitation_code function
-- Description: تحديث دالة التحقق من كود الدعوة لتبحث في 
--   teacher_enrollments.invitation_code بالإضافة إلى 
--   teacher_invitations.code
-- Date: 2026-01-20
-- =============================================

-- أولاً: حذف الدالة القديمة
DROP FUNCTION IF EXISTS public.verify_invitation_code(text);

-- ثانياً: إنشاء الدالة الجديدة
CREATE OR REPLACE FUNCTION public.verify_invitation_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- ============ كود ولي أمر (يبدأ بـ P) ============
    IF UPPER(SUBSTRING(p_code FROM 1 FOR 1)) = 'P' THEN
        SELECT jsonb_build_object(
            'valid', true,
            'type', 'parent',
            'student_name', COALESCE(s.full_name, 'طالب'),
            'center_name', c.name,
            'already_used', se.parent_code_status = 'claimed'
        )
        INTO v_result
        FROM public.student_enrollments se
        LEFT JOIN public.students s ON se.student_id = s.id
        LEFT JOIN public.centers c ON se.center_id = c.id
        WHERE UPPER(se.parent_invitation_code) = UPPER(p_code)
        LIMIT 1;
        
        IF v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
        
        -- إذا لم يتم العثور على الكود
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'كود ولي الأمر غير صحيح'
        );
    END IF;
    
    -- ============ كود معلم (يبدأ بـ T) ============
    IF UPPER(SUBSTRING(p_code FROM 1 FOR 1)) = 'T' THEN
        -- 1. البحث أولاً في teacher_invitations
        SELECT jsonb_build_object(
            'valid', true,
            'type', 'teacher',
            'teacher_name', ti.teacher_name,
            'center_name', c.name,
            'center_id', c.id,
            'already_used', COALESCE(ti.used, false),
            'expired', ti.expires_at IS NOT NULL AND ti.expires_at < NOW(),
            'source', 'teacher_invitations'
        )
        INTO v_result
        FROM public.teacher_invitations ti
        JOIN public.centers c ON ti.center_id = c.id
        WHERE UPPER(ti.code) = UPPER(p_code)
        LIMIT 1;
        
        IF v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
        
        -- 2. البحث في teacher_enrollments (fallback)
        SELECT jsonb_build_object(
            'valid', true,
            'type', 'teacher',
            'teacher_name', COALESCE(u.full_name, 'معلم'),
            'center_name', c.name,
            'center_id', c.id,
            'teacher_user_id', te.teacher_user_id,
            'enrollment_id', te.id,
            'already_used', te.teacher_user_id IS NOT NULL AND te.status = 'active',
            'expired', false,
            'source', 'teacher_enrollments'
        )
        INTO v_result
        FROM public.teacher_enrollments te
        JOIN public.centers c ON te.center_id = c.id
        LEFT JOIN public.users u ON te.teacher_user_id = u.id
        WHERE UPPER(te.invitation_code) = UPPER(p_code)
          AND te.deleted_at IS NULL
        LIMIT 1;
        
        IF v_result IS NOT NULL THEN
            RETURN v_result;
        END IF;
        
        -- إذا لم يتم العثور على الكود
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'كود المعلم غير صحيح'
        );
    END IF;
    
    -- كود غير معروف النوع
    RETURN jsonb_build_object(
        'valid', false,
        'error', 'كود غير صحيح - يجب أن يبدأ بـ P (ولي أمر) أو T (معلم)'
    );
END;
$$;

-- منح الصلاحيات
ALTER FUNCTION public.verify_invitation_code(p_code text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.verify_invitation_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_invitation_code(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_invitation_code(text) TO service_role;

-- ============ اختبار الدالة ============
-- SELECT verify_invitation_code('T6264689');
-- SELECT verify_invitation_code('TA45C9F7');
-- SELECT verify_invitation_code('TB050235');
