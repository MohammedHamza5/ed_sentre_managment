# الأسبوع الأول - خطة التنفيذ
# Week 1 Implementation Plan

**الفترة**: 15-21 ديسمبر 2025  
**التركيز**: الأمان وRLS والصلاحيات

---

## 📅 اليوم 1-2: إعداد RLS للجداول الأساسية

### المهام
- [ ] تطبيق RLS Policies على جداول Students
- [ ] تطبيق RLS Policies على جداول Teachers  
- [ ] تطبيق RLS Policies على جداول Courses
- [ ] تطبيق RLS Policies على جداول Classrooms

### خطوات التنفيذ

#### 1. فتح Supabase SQL Editor
```
Dashboard → SQL Editor → New Query
```

#### 2. تطبيق Helper Functions أولاً
```sql
-- نسخ ولصق من docs/rls_policies.sql
-- القسم: HELPER FUNCTIONS
```

#### 3. تطبيق policies لكل جدول
```sql
-- نسخ ولصق policies لكل جدول
-- ابدأ بـ STUDENTS TABLE
-- ثم TEACHERS TABLE
-- إلخ...
```

#### 4. التحقق
```sql
-- التحقق من تفعيل RLS
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('students', 'teachers', 'courses', 'classrooms')
ORDER BY tablename;

-- يجب أن تظهر rowsecurity = true لكل جدول
```

### الاختبار
1. قم بتسجيل الدخول كـ Center Admin
2. حاول عرض الطلاب - يجب أن يعمل
3. قم بتسجيل الدخول كـ Teacher  
4. حاول عرض الطلاب - يجب أن يعمل
5. حاول حذف طالب - يجب أن يفشل (ليس لديه صلاحية)

---

## 📅 اليوم 3: تطبيق RoleProvider في التطبيق

### المهام
- [x] إنشاء RoleProvider (✅ تم)
- [ ] تحديث AuthBloc لتحميل الدور
- [ ] إضافة Permission Checks في الواجهات
- [ ] اختبار الصلاحيات

### خطوات التنفيذ

#### 1. تحديث AuthBloc
```dart
// في lib/features/auth/bloc/auth_bloc.dart
// بعد تسجيل الدخول الناجح:
on<AuthLoginRequested>((event, emit) async {
  
  // Initialize role after login
  final roleProvider = context.read<RoleProvider>();
  await roleProvider.initialize();
  
  emit(AuthAuthenticated(user: user));
});
```

#### 2. إضافة Permission Checks للأزرار
```dart
// مثال: زر "إضافة طالب"
Consumer<RoleProvider>(
  builder: (context, roleProvider, child) {
    if (!roleProvider.hasPermission(Permission.addStudent)) {
      return const SizedBox.shrink();
    }
    
    return ElevatedButton(
      onPressed: () => context.go('/students/add'),
      child: const Text('إضافة طالب'),
    );
  },
)
```

#### 3. إضافة Checks للصفحات
```dart
// في add_student_screen.dart
@override
Widget build(BuildContext context) {
  final roleProvider = context.watch<RoleProvider>();
  
  if (!roleProvider.hasPermission(Permission.addStudent)) {
    return Scaffold(
      body: Center(
        child: Text('ليس لديك صلاحية للوصول لهذه الصفحة'),
      ),
    );
  }
  
  // ... rest of UI
}
```

### الاختبار
1. سجل دخول كـ Center Admin
   - يجب أن ترى جميع الأزرار والخيارات
2. سجل دخول كـ Teacher
   - يجب ألا ترى أزرار الحذف
   - لا يمكنك الوصول لصفحة إضافة طالب
3. سجل دخول كـ Accountant
   - يمكنك الوصول للمدفوعات
   - لا يمكنك حذف طلاب

---

## 📅 اليوم 4: RLS للجداول المتبقية

### المهام
- [ ] تطبيق RLS على Schedules
- [ ] تطبيق RLS على Attendance
- [ ] تطبيق RLS على Payments
- [ ] تطبيق RLS على Grades

### خطوات التنفيذ
نفس خطوات اليوم 1-2، لكن للجداول المتبقية

### الاختبار
```sql
-- التحقق من جميع الجداول
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
  'students', 'teachers', 'courses', 'classrooms',
  'schedules', 'attendance', 'payments', 'grades'
)
ORDER BY tablename;

-- جميع الجداول يجب أن تكون rowsecurity = true
```

---

## 📅 اليوم 5: مراجعة وتوثيق واختبار

### المهام
- [ ] اختبار شامل لجميع السيناريوهات
- [ ] توثيق السياسات المطبقة
- [ ] إنشاء test users مع أدوار مختلفة
- [ ] كتابة تقرير الأسبوع

### سيناريوهات الاختبار

#### سيناريو 1: Super Admin
```
✓ يرى جميع المراكز
✓ يرى جميع الطلاب من كل المراكز
✓ يمكنه الحذف من أي مركز
```

#### سيناريو 2: Center Admin
```
✓ يرى فقط مركزه
✓ يرى فقط طلاب مركزه
✓ يمكنه إضافة/تعديل/حذف في مركزه
✗ لا يمكنه رؤية بيانات مراكز أخرى
```

#### سيناريو 3: Teacher
```
✓ يرى طلاب المواد التي يدرسها
✓ يمكنه تسجيل الحضور
✓ يمكنه إضافة درجات
✗ لا يمكنه حذف طلاب
✗ لا يمكنه رؤية المدفوعات
```

#### سيناريو 4: Accountant
```
✓ يرى جميع المدفوعات في مركزه
✓ يمكنه إضافة/تعديل مدفوعات
✗ لا يمكنه حذف طلاب
✗ لا يمكنه تعديل الحضور
```

### إنشاء Test Users

```sql
-- Super Admin
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES (
  'superadmin@test.com',
  crypt('Test123!', gen_salt('bf')),
  now(),
  '{"role": "super_admin"}'::jsonb
);

-- Center Admin
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES (
  'admin@center1.com',
  crypt('Test123!', gen_salt('bf')),
  now(),
  '{"role": "center_admin", "center_id": "your-center-uuid-here"}'::jsonb
);

-- Teacher
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES (
  'teacher@center1.com',
  crypt('Test123!', gen_salt('bf')),
  now(),
  '{"role": "teacher", "center_id": "your-center-uuid-here"}'::jsonb
);

-- Accountant
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES (
  'accountant@center1.com',
  crypt('Test123!', gen_salt('bf')),
  now(),
  '{"role": "accountant", "center_id": "your-center-uuid-here"}'::jsonb
);
```

### التوثيق

#### ملف: docs/rls_implementation_status.md
```markdown
# RLS Implementation Status

## ✅ Completed Tables
- [x] students
- [x] student_centers  
- [x] teachers
- [x] teacher_centers
- [x] courses
- [x] classrooms
- [x] schedules
- [x] attendance
- [x] payments
- [x] grades

## 🧪 Test Results
- [x] Super Admin: All permissions working
- [x] Center Admin: Isolated to own center
- [x] Teacher: Limited to teaching functions
- [x] Accountant: Limited to financial data

## 📝 Notes
- All policies tested with multiple users
- Performance impact: minimal (< 50ms overhead)
- No data leakage detected between centers
```

---

## 📊 مؤشرات النجاح للأسبوع الأول

- [x] RLS مفعل على جميع الجداول الأساسية
- [x] RoleProvider يعمل بشكل صحيح
- [x] Permission Checks مطبقة في الواجهات
- [x] Test Users بأدوار مختلفة تعمل
- [x] لا يوجد data leakage بين المراكز
- [x] التوثيق محدث

---

## 🎯 تسليمات الأسبوع

### ملفات جديدة
- [x] `lib/core/auth/role_provider.dart`
- [x] `lib/core/error/result.dart`
- [x] `lib/core/error/error_handler.dart`
- [x] `docs/rls_policies.sql`
- [ ] `docs/rls_implementation_status.md`

### ملفات محدثة
- [x] `lib/main.dart` - إضافة RoleProvider
- [ ] `lib/features/auth/bloc/auth_bloc.dart` - تحميل الدور
- [ ] `lib/features/students/presentation/screens/*.dart` - Permission Checks
- [ ] `lib/features/teachers/presentation/screens/*.dart` - Permission Checks

### قاعدة البيانات
- [ ] RLS policies مطبقة على Supabase
- [ ] Test users منشأة
- [ ] Verification queries تعمل

---

## 🚧 المشاكل المحتملة

### مشكلة: "Permission denied for table"
**الحل**: 
1. تحقق من أن RLS مفعل
2. تحقق من أن JWT يحتوي على role
3. راجع السياسة للجدول

### مشكلة: "User can see data from other centers"
**الحل**:
1. تحقق من أن center_id في JWT صحيح
2. راجع سياسة USING و WITH CHECK
3. اختبر Query يدوياً في SQL Editor

### مشكلة: "RoleProvider shows guest role"
**الحل**:
1. تحقق من أن initialize() تم استدعاؤه
2. تحقق من أن userMetadata يحتوي على role
3. راجع _parseRole() function

---

**الموعد النهائي**: 21 ديسمبر 2025  
**المسؤول**: Development Team  
**الحالة**: 🟡 قيد التنفيذ
