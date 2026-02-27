# 🔧 إصلاح مشكلة التسجيل - Infinite Recursion في RLS

## 📋 الملخص

عند تسجيل مستخدم جديد، يتم إنشاؤه في `auth.users` بنجاح، ولكن يفشل في الإضافة إلى الجداول الأخرى بسبب خطأ:

```
infinite recursion detected in policy for relation "user_centers"
```

## 🎯 الحل السريع (5 دقائق)

### 1️⃣ افتح Supabase Dashboard

1. انتقل إلى: https://supabase.com/dashboard
2. اختر مشروعك: `mbmqrmgdgygznbqvvfqi`
3. اذهب إلى: **SQL Editor** (من القائمة الجانبية)

### 2️⃣ نفذ السكريبت

1. افتح ملف `docs/fix_rls_infinite_recursion.sql` من مشروعك
2. انسخ المحتوى **بالكامل** (200 سطر)
3. الصقه في SQL Editor في Supabase
4. اضغط زر **Run** أو **Execute** (Ctrl+Enter)

### 3️⃣ تحقق من النجاح

يجب أن ترى في الـ Output:

```
SUCCESS: Query executed successfully
Rows returned: X (قائمة السياسات الجديدة)
```

### 4️⃣ اختبر التسجيل

الآن شغل التطبيق وجرب التسجيل مرة أخرى:

```powershell
flutter run -d windows --dart-define=SUPABASE_URL=https://mbmqrmgdgygznbqvvfqi.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

## ✅ النتيجة المتوقعة

بعد تطبيق الإصلاح، عند التسجيل:

```
🔵 بداية عملية التسجيل للمستخدم: test@example.com
✅ تم إنشاء المستخدم في Auth بنجاح - ID: xxx-xxx-xxx
🔵 إنشاء مركز تجريبي...
✅ تم إنشاء المركز بنجاح - Center ID: yyy-yyy-yyy
🔵 إضافة المستخدم إلى جدول users...
✅ تم إضافة المستخدم إلى جدول users بنجاح
🔵 ربط المستخدم بالمركز...
✅ تم ربط المستخدم بالمركز بنجاح
🔵 تحديث بيانات Auth metadata...
✅ تم تحديث Auth metadata بنجاح
🔵 جلب بيانات المستخدم النهائية...
✅ اكتملت عملية التسجيل بنجاح!
```

**لن يظهر الخطأ:** ❌ `Error fetching user data: PostgrestException(... infinite recursion ...)`

## 🔍 التحقق من البيانات

بعد التسجيل الناجح، تحقق في Supabase من الجداول التالية:

### جدول `auth.users`
```sql
SELECT id, email, created_at FROM auth.users ORDER BY created_at DESC LIMIT 1;
```
يجب أن يظهر المستخدم الجديد ✅

### جدول `public.users`
```sql
SELECT id, full_name, phone, role, is_active FROM public.users ORDER BY created_at DESC LIMIT 1;
```
يجب أن يظهر المستخدم مع `is_active = true` ✅

### جدول `public.centers`
```sql
SELECT id, name, license_number, is_active FROM public.centers ORDER BY created_at DESC LIMIT 1;
```
يجب أن يظهر المركز الجديد ✅

### جدول `public.user_centers`
```sql
SELECT user_id, center_id, role, is_active FROM public.user_centers ORDER BY created_at DESC LIMIT 1;
```
يجب أن يظهر الربط بين المستخدم والمركز ✅

## 🧪 اختبار تسجيل الدخول

بعد التسجيل، جرب تسجيل الدخول بنفس البيانات:
- يجب أن يتم تسجيل الدخول بنجاح
- يجب أن يتم التوجيه إلى Dashboard
- لن يظهر أي أخطاء RLS

## 🛠️ ماذا فعل السكريبت؟

السكريبت قام بـ:

1. **حذف السياسات القديمة** المتضاربة على:
   - `user_centers` (9 سياسات)
   - `users` (جميع السياسات)
   - `centers` (جميع السياسات)

2. **إنشاء سياسات جديدة بسيطة** بدون infinite recursion:
   - `users_select_self` - المستخدم يرى بياناته
   - `users_update_self` - المستخدم يحدث بياناته
   - `users_insert_new` - السماح بالتسجيل
   - `user_centers_select_own` - المستخدم يرى ارتباطاته
   - `user_centers_insert_own` - المستخدم ينشئ ارتباطات
   - `user_centers_update_own` - المستخدم يحدث ارتباطاته
   - `centers_select_linked` - المستخدم يرى مراكزه
   - `centers_update_linked` - المستخدم يحدث مراكزه
   - `centers_insert_new` - السماح بإنشاء مراكز (للتطوير)

3. **التحقق** من السياسات الجديدة عبر query نهائي

## 📚 مراجع إضافية

- [دليل حل المشاكل الكامل](./TROUBLESHOOTING.md)
- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)

## ❓ أسئلة شائعة

### س: هل سيؤثر هذا على المستخدمين الموجودين؟
**ج:** لا، السياسات الجديدة متوافقة مع البيانات الموجودة.

### س: هل يمكنني التراجع عن التغييرات؟
**ج:** نعم، يمكنك استعادة السياسات القديمة من `full_schema.sql` (السطور 22040-26000)، لكن المشكلة ستعود.

### س: هل أحتاج لتطبيق هذا في الإنتاج أيضاً؟
**ج:** نعم، المشكلة موجودة في كل من Development و Production.

### س: لماذا حدثت المشكلة؟
**ج:** السياسات القديمة كانت تبحث في `user_centers` من داخل سياسة على `user_centers` نفسه، مما سبب حلقة لا نهائية.

---

## 🚀 ما التالي؟

بعد حل المشكلة:

1. ✅ اختبر التسجيل والدخول عدة مرات
2. ✅ راجع [خطة الأسبوع الأول](./WEEK_1_IMPLEMENTATION.md)
3. 🔄 أضف سياسات متقدمة بناءً على JWT roles (اختياري)
4. 🔄 أضف Email Confirmation للإنتاج
5. 🔄 راجع [خطة التطوير الكاملة](./project_analysis_and_plan.md)

---

**✨ بالتوفيق في تطوير EdSentre!**
