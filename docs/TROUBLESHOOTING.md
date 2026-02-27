# دليل حل المشاكل - Troubleshooting Guide

## المشكلة الحالية: Infinite Recursion في RLS Policies

### الأعراض:
```
! Error fetching user data: PostgrestException(
  message: {"code":"42P17","details":null,"hint":null,
  "message":"infinite recursion detected in policy for relation \"user_centers\""},
  code: 500, details: Internal Server Error, hint: null
)
```

### السبب:
السياسات الموجودة على جدول `user_centers` تحتوي على استعلامات فرعية (subqueries) تبحث في نفس الجدول `user_centers`، مما يسبب **حلقة لا نهائية**.

مثال على السياسة المشكلة:
```sql
CREATE POLICY "Center admins can view users in their center" 
ON public.user_centers 
FOR SELECT
USING ((EXISTS ( 
  SELECT 1
  FROM public.centers uc_admin  -- ❌ يبحث في user_centers ذاته
  WHERE uc_admin.user_id = auth.uid()
  AND uc_admin.id = user_centers.id
  ...
)));
```

### الحل:

#### الخطوة 1️⃣: تطبيق الإصلاح على Supabase

1. **افتح Supabase Dashboard**
   - انتقل إلى: https://supabase.com/dashboard
   - اختر مشروعك
   - انتقل إلى: SQL Editor

2. **نفذ سكريبت الإصلاح**
   - افتح ملف: `docs/fix_rls_infinite_recursion.sql`
   - انسخ المحتوى بالكامل
   - الصقه في SQL Editor
   - اضغط **Run**

3. **تحقق من النتائج**
   - يجب أن ترى رسالة: `Query executed successfully`
   - في نهاية السكريبت، سترى قائمة بالسياسات الجديدة

#### الخطوة 2️⃣: اختبار التسجيل

بعد تطبيق الإصلاح، جرب التسجيل مرة أخرى:

```bash
flutter run -d windows --dart-define=SUPABASE_URL=https://mbmqrmgdgygznbqvvfqi.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### الخطوة 3️⃣: التحقق من البيانات

بعد التسجيل الناجح، تحقق من الجداول في Supabase:

1. **جدول `auth.users`**
   ```sql
   SELECT id, email, created_at, raw_user_meta_data 
   FROM auth.users 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```

2. **جدول `public.users`**
   ```sql
   SELECT id, full_name, phone, role, is_active, default_center_id
   FROM public.users
   ORDER BY created_at DESC
   LIMIT 5;
   ```

3. **جدول `public.centers`**
   ```sql
   SELECT id, name, license_number, is_active, created_at
   FROM public.centers
   ORDER BY created_at DESC
   LIMIT 5;
   ```

4. **جدول `public.user_centers`**
   ```sql
   SELECT uc.user_id, uc.center_id, uc.role, uc.is_active,
          u.full_name as user_name,
          c.name as center_name
   FROM public.user_centers uc
   LEFT JOIN public.users u ON uc.user_id = u.id
   LEFT JOIN public.centers c ON uc.center_id = c.id
   ORDER BY uc.created_at DESC
   LIMIT 5;
   ```

---

## مشاكل شائعة أخرى

### 1. المستخدم موجود في auth.users ولكن ليس في public.users

**السبب:** فشلت خطوة إدراج المستخدم في `public.users`

**الحل:**
```sql
-- البحث عن المستخدم في Auth فقط
SELECT id, email, created_at 
FROM auth.users 
WHERE email = 'البريد_الإلكتروني_هنا';

-- إضافة المستخدم يدوياً إلى public.users
INSERT INTO public.users (id, full_name, phone, role, is_active)
VALUES (
  'user_id_من_auth.users',
  'الاسم الكامل',
  'رقم الهاتف',
  'center_admin',
  true
);
```

### 2. المستخدم موجود في users ولكن ليس في user_centers

**السبب:** فشلت خطوة ربط المستخدم بالمركز

**الحل:**
```sql
-- البحث عن المركز
SELECT id, name FROM public.centers ORDER BY created_at DESC LIMIT 5;

-- ربط المستخدم بالمركز
INSERT INTO public.user_centers (user_id, center_id, role, is_active)
VALUES (
  'user_id_هنا',
  'center_id_هنا',
  'center_admin',
  true
);

-- تحديث default_center_id في جدول users
UPDATE public.users
SET default_center_id = 'center_id_هنا'
WHERE id = 'user_id_هنا';
```

### 3. لا يمكن تسجيل الدخول بعد التسجيل

**السبب:** الحساب غير مفعّل (`is_active = false`)

**الحل:**
```sql
-- تفعيل الحساب
UPDATE public.users
SET is_active = true
WHERE email IN (
  SELECT email FROM auth.users WHERE id = 'user_id_هنا'
);
```

### 4. خطأ "User not in the system"

**السبب:** `_fetchUserData` لا يجد بيانات المستخدم بسبب RLS

**الحل:**
- تأكد من تطبيق سكريبت `fix_rls_infinite_recursion.sql`
- تحقق من وجود سياسة `users_select_self` في Supabase

```sql
-- التحقق من السياسات
SELECT * FROM pg_policies 
WHERE tablename = 'users' 
AND policyname = 'users_select_self';
```

---

## تشخيص المشاكل

### عرض جميع سياسات RLS على جدول معين

```sql
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_centers'  -- أو users أو centers
ORDER BY policyname;
```

### تعطيل RLS مؤقتاً للاختبار (⚠️ خطير في الإنتاج)

```sql
-- تعطيل RLS على جدول معين
ALTER TABLE public.user_centers DISABLE ROW LEVEL SECURITY;

-- إعادة تفعيل RLS
ALTER TABLE public.user_centers ENABLE ROW LEVEL SECURITY;
```

### عرض صلاحيات المستخدم الحالي

في التطبيق، يمكنك طباعة JWT claims:

```dart
final user = SupabaseClientManager.currentUser;
if (user != null) {
  print('User ID: ${user.id}');
  print('Email: ${user.email}');
  print('Metadata: ${user.userMetadata}');
  print('App Metadata: ${user.appMetadata}');
}
```

---

## الخطوات التالية بعد حل المشكلة

1. ✅ تطبيق `fix_rls_infinite_recursion.sql`
2. ✅ اختبار التسجيل بنجاح
3. ✅ التحقق من إضافة البيانات في جميع الجداول
4. 🔄 إضافة سياسات RLS متقدمة بناءً على الأدوار (اختياري)
5. 🔄 إضافة triggers للتحديثات التلقائية (اختياري)
6. 🔄 إعداد Email Confirmation (في الإنتاج)

---

## جهات الاتصال والمساعدة

- **Supabase Documentation:** https://supabase.com/docs/guides/auth/row-level-security
- **PostgreSQL RLS:** https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **Flutter Supabase:** https://supabase.com/docs/guides/getting-started/tutorials/with-flutter

---

## Checklist للتسجيل الناجح

- [ ] المستخدم موجود في `auth.users`
- [ ] المستخدم موجود في `public.users`
- [ ] المركز موجود في `public.centers` (في وضع التطوير)
- [ ] الربط موجود في `public.user_centers`
- [ ] `is_active = true` في جدول `users`
- [ ] `is_active = true` في جدول `user_centers`
- [ ] `default_center_id` محدد في جدول `users`
- [ ] السياسات RLS لا تسبب infinite recursion
- [ ] يمكن تسجيل الدخول بنجاح
- [ ] يتم الانتقال إلى Dashboard

---

**آخر تحديث:** 2025-12-15
**الإصدار:** 1.0
