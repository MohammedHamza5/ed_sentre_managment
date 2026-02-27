# دليل تنفيذ سياسات RLS (.Row Level Security)

## نظرة عامة

يقدم هذا الدليل إرشادات تفصيلية حول كيفية تنفيذ سياسات الأمان على مستوى الصفوف (RLS) في مشروع EdSentre لضمان عزل البيانات بين المراكز التعليمية المختلفة.

## المتطلبات الأساسية

- قاعدة بيانات Supabase
- تطبيق Flutter مُعد مسبقًا
- فهم جيد لنموذج تعدد المستأجرين (Multi-tenancy)

## الخطوات المطلوبة

### 1. تفعيل RLS على الجداول

تأكد من تفعيل RLS على جميع الجداول المطلوبة:

```sql
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_centers ENABLE ROW LEVEL SECURITY;
```

### 2. إنشاء الدوال المساعدة

أنشئ الدوال التالية لتسهيل الوصول إلى معلومات المستخدم:

```sql
-- الحصول على مركز المستخدم الحالي
CREATE OR REPLACE FUNCTION auth.user_center_id() 
RETURNS uuid AS $$
  SELECT COALESCE(
    (auth.jwt()->>'center_id')::uuid,
    (auth.jwt()->>'default_center_id')::uuid
  );
$$ LANGUAGE SQL STABLE;

-- الحصول على دور المستخدم الحالي
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS text AS $$
  SELECT COALESCE(
    auth.jwt()->>'role',
    auth.jwt()->>'user_type',
    'guest'
  );
$$ LANGUAGE SQL STABLE;

-- التحقق مما إذا كان المستخدم هو المشرف العام
CREATE OR REPLACE FUNCTION auth.is_super_admin()
RETURNS boolean AS $$
  SELECT auth.user_role() IN ('super_admin', 'superadmin');
$$ LANGUAGE SQL STABLE;

-- التحقق مما إذا كان المستخدم هو مدير المركز
CREATE OR REPLACE FUNCTION auth.is_center_admin()
RETURNS boolean AS $$
  SELECT auth.user_role() IN ('center_admin', 'centeradmin', 'admin');
$$ LANGUAGE SQL STABLE;
```

### 3. تطبيق السياسات على الجداول

#### جدول الطلاب (students)

```sql
-- العرض: أي شخص لديه حق الوصول إلى المركز
CREATE POLICY "view_students"
ON public.students
FOR SELECT
TO authenticated
USING (
  auth.is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.student_centers sc
    WHERE sc.student_id = students.id
    AND sc.center_id = auth.user_center_id()
    AND auth.user_role() IN ('center_admin', 'admin', 'coordinator', 'accountant', 'teacher')
  )
);

-- الإدارة: مدير المركز والمُنسق فقط
CREATE POLICY "manage_students"
ON public.students
FOR ALL
TO authenticated
USING (
  auth.is_super_admin()
  OR (
    auth.user_role() IN ('center_admin', 'admin', 'coordinator')
    AND EXISTS (
      SELECT 1 FROM public.student_centers sc
      WHERE sc.student_id = students.id
      AND sc.center_id = auth.user_center_id()
    )
  )
)
WITH CHECK (
  auth.is_super_admin()
  OR auth.user_role() IN ('center_admin', 'admin', 'coordinator')
);
```

#### جدول المعلمين (teachers)

```sql
-- العرض: أي شخص لديه حق الوصول إلى المركز
CREATE POLICY "view_teachers"
ON public.teachers
FOR SELECT
TO authenticated
USING (
  auth.is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.teacher_centers tc
    WHERE tc.teacher_id = teachers.id
    AND tc.center_id = auth.user_center_id()
  )
);

-- الإدارة: مدير المركز فقط
CREATE POLICY "manage_teachers"
ON public.teachers
FOR ALL
TO authenticated
USING (
  auth.is_super_admin()
  OR (
    auth.user_role() IN ('center_admin', 'admin')
    AND EXISTS (
      SELECT 1 FROM public.teacher_centers tc
      WHERE tc.teacher_id = teachers.id
      AND tc.center_id = auth.user_center_id()
    )
  )
)
WITH CHECK (
  auth.is_super_admin()
  OR auth.user_role() IN ('center_admin', 'admin');
);
```

(تابع تطبيق السياسات المشابهة على باقي الجداول كما هو موضح في ملف `advanced_rls_policies.sql`)

## اختبار السياسات

### 1. اختبار عزل البيانات

تأكد من أن كل مستخدم يرى فقط البيانات المتعلقة بمركزه:

```sql
-- تسجيل دخول مستخدم عادي
-- ثم تنفيذ استعلام لعرض الطلاب
SELECT * FROM public.students;
-- يجب أن تعرض فقط الطلاب المرتبطين بمركز المستخدم
```

### 2. اختبار الأدوار المختلفة

- اختبر السياسات مع مستخدمين من أدوار مختلفة (مدير مركز، معلم، محاسب، إلخ)
- تأكد من أن كل دور لديه الوصول المناسب فقط

### 3. اختبار المشرف العام

- سجل دخول مستخدم بمسمى "super_admin"
- تأكد من أنه يستطيع رؤية جميع البيانات من جميع المراكز

## أفضل الممارسات

### 1. الأداء

- أضف فهارس على أعمدة `center_id` لتحسين الأداء
- استخدم العروض المادية للبيانات المعقدة

### 2. الصيانة

- وثّق كل سياسة بوضوح
- استخدم أسماء واضحة للسياسات
- راقب أداء الاستعلامات بانتظام

### 3. الأمان

- لا تضع معلومات حساسة في JWT claims
- استخدم HTTPS دائمًا
- راقب محاولات الوصول غير المصرح بها

## استكشاف الأخطاء وإصلاحها

### مشكلة التكرار اللانهائي (Infinite Recursion)

تجنب استخدام استعلامات فرعية تشير إلى نفس الجدول:

```sql
-- ❌ غير صحيح - يسبب تكرار لانهائي
CREATE POLICY problematic_policy
ON public.user_centers
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_centers uc2  -- نفس الجدول
    WHERE uc2.user_id = auth.uid()
  )
);

-- ✅ صحيح - لا يسبب تكرار لانهائي
CREATE POLICY correct_policy
ON public.user_centers
FOR SELECT
TO authenticated
USING (user_id = auth.uid());
```

### مشكلة الوصول الممنوع

إذا كان المستخدمون لا يستطيعون الوصول إلى بياناتهم:

1. تحقق من أن JWT token يحتوي على `center_id` أو `default_center_id`
2. تحقق من أن قيمة `role` أو `user_type` صحيحة
3. راجع سياسات RLS للجدول المعني

## الخلاصة

تنفيذ سياسات RLS بشكل صحيح يضمن:

1. عزل البيانات بين المراكز المختلفة
2. أمان أفضل للبيانات
3. التحكم الدقيق في الوصول بناءً على الأدوار
4. توافق مع معايير الحماية والخصوصية

تذكر دائمًا اختبار السياسات بعناية قبل نشرها في بيئة الإنتاج.