# 🔧 تقرير مشاكل تكامل تطبيق الطالب مع تطبيق الإدارة

## 📋 ملخص تنفيذي

هذا التقرير يوضح المشاكل التي تم اكتشافها في تطبيق الطالب والتي تتطلب إصلاحات من جانب **تطبيق الإدارة (Admin App)**.

---

## 🔴 المشكلة 1: بيانات الطالب غير مكتملة

### الوصف
عند فتح الملف الشخصي للطالب، العديد من الحقول تظهر فارغة:
- كود الطالب (`student_code`)
- السنة الدراسية (`academic_year`)
- اسم المدرسة (`school_name`)
- العنوان (`address`)

### السبب الجذري
تطبيق الإدارة **لا يُعبئ هذه الحقول** عند إضافة أو تعديل الطالب في جدول `students`.

### الحل المطلوب
في شاشة **إضافة/تعديل الطالب** بتطبيق الإدارة:

```dart
// عند حفظ الطالب، تأكد من إرسال كل الحقول
await supabase.from('students').upsert({
  'user_id': userId,
  'full_name': studentName,
  'student_code': generateStudentCode(), // مهم!
  'academic_year': selectedGrade,         // مهم!
  'school_name': schoolName,              // مهم!
  'phone': phone,
  'address': address,
  'birth_date': birthDate,
  'parent_phone': parentPhone,
  'guardian_name': guardianName,
  // ... باقي الحقول
});
```

### الجدول المتأثر
```sql
-- جدول students يجب أن يحتوي على:
student_code    TEXT    -- كود فريد للطالب (مثل STU-001)
academic_year   TEXT    -- الصف الدراسي (مثل "الصف الثالث الثانوي")
school_name     TEXT    -- اسم المدرسة
```

---

## 🔴 المشكلة 2: البريد الإلكتروني المُولّد

### الوصف
البريد الإلكتروني للطالب يظهر بصيغة غريبة:
```
69fe46d7@student.edsentre.com
```

### السبب الجذري
عند إنشاء الطالب، النظام يُولّد بريد إلكتروني عشوائي بدلاً من استخدام بريد حقيقي.

### الحل المطلوب
**خيار 1:** السماح للطالب بإدخال بريده الإلكتروني الحقيقي عند التسجيل.

**خيار 2:** تحديث البريد من تطبيق الإدارة:
```dart
await supabase.from('students').update({
  'email': realEmail,
}).eq('id', studentId);
```

---

## 🔴 المشكلة 3: ربط المعلم بالمجموعات

### الوصف
اسم المعلم لا يظهر في المقررات والجدول.

### السبب الجذري
عند إنشاء المجموعة، الـ `teacher_id` المحفوظ في جدول `groups` **لا يتطابق** مع أي مستخدم في جدول `users`.

#### البنية الحالية (الخاطئة):
```
groups.teacher_id → ❌ ID غير موجود في users
```

#### البنية الصحيحة:
```
groups.teacher_id → teachers.id → teachers.user_id → users.id → users.full_name
```

### الحل المطلوب
في شاشة **إنشاء/تعديل المجموعة** عند اختيار المعلم:

```dart
// عند اختيار المعلم، استخدم teachers.id وليس users.id
final selectedTeacher = await showTeacherPicker();
await supabase.from('groups').update({
  'teacher_id': selectedTeacher.id, // من جدول teachers
}).eq('id', groupId);
```

### أو تغيير الـ RPC ليمر عبر جدول teachers:
تم إصلاح هذا في تطبيق الطالب بالكود التالي:
```sql
LEFT JOIN teachers t ON g.teacher_id = t.id
LEFT JOIN users u ON t.user_id = u.id
```

---

## 🔴 المشكلة 4: ترتيب أيام الأسبوع

### الوصف
الجدول الدراسي يظهر في أيام خاطئة.

### السبب الجذري
تطبيق الإدارة يحفظ `day_of_week` بترتيب عربي:
- 0 = السبت
- 1 = الأحد
- 2 = الإثنين
- ...
- 6 = الجمعة

لكن Dart `DateTime.weekday` يستخدم:
- 1 = الإثنين
- 7 = الأحد

### الحل المطلوب
**تم حله** من جانب تطبيق الطالب. لا يتطلب تغيير من الإدارة.

## 🔴 المشكلة 5: لا توجد سجلات مدفوعات للطلاب

### الوصف
شاشة المدفوعات تظهر "0 مستحقات" رغم تسجيل الطالب في مواد.

### السبب الجذري
عند تسجيل طالب في مادة، تطبيق الإدارة **لا يُنشئ سجل مدفوعات** في جدول `payments`.

### نتيجة الفحص
```
RPC: get_student_payments → SUCCESS | count: 0
```

### الحل المطلوب
عند تسجيل طالب في مادة أو مجموعة، يجب إنشاء سجل مدفوعات:

```dart
// عند تسجيل الطالب في مادة
await supabase.from('payments').insert({
  'student_user_id': studentUserId,
  'student_id': studentId,
  'course_id': courseId,
  'center_id': centerId,
  'amount': coursePrice,
  'paid_amount': 0,
  'status': 'pending',
  'due_date': calculateDueDate(),
  'description': 'رسوم مادة ${courseName} - ${monthName}',
});
```

### الجدول المتأثر
```sql
-- جدول payments يجب أن يحتوي على:
student_user_id  UUID      -- معرف المستخدم
student_id       UUID      -- معرف الطالب
course_id        UUID      -- معرف المادة
center_id        UUID      -- معرف المركز
amount           NUMERIC   -- المبلغ المستحق
paid_amount      NUMERIC   -- المبلغ المدفوع
status           TEXT      -- pending/paid/partial/overdue
due_date         DATE      -- تاريخ الاستحقاق
```

---

## � المشكلة 6: لا يظهر أي معلمين في شاشة الرسائل

### الوصف
شاشة الرسائل فارغة ولا تظهر أي معلمين للتواصل معهم رغم تسجيل الطالب في مجموعات.

### نتيجة الفحص
```
RPC: get_available_teachers → [] (0 معلمين)
RPC: get_student_conversations → [] (0 محادثات)
```

### السبب الجذري المحتمل
1. RPC `get_available_teachers` لا يجد المعلمين المرتبطين بمجموعات الطالب
2. ربط `teacher_id` في جدول `groups` غير صحيح (نفس مشكلة #3)

### الحل المطلوب
التأكد من أن RPC `get_available_teachers` يستعلم بشكل صحيح:

```sql
-- يجب أن يبحث عن المعلمين عبر:
-- student_group_enrollments → groups → teachers → users

SELECT DISTINCT
  u.id,
  u.full_name,
  u.avatar_url
FROM student_group_enrollments sge
JOIN groups g ON sge.group_id = g.id
JOIN teachers t ON g.teacher_id = t.id  -- عبر جدول teachers
JOIN users u ON t.user_id = u.id
WHERE sge.student_id = p_student_id
  AND g.center_id = p_center_id
  AND sge.status = 'active';
```

### أو من جانب تطبيق الإدارة
التأكد من:
1. تعيين `teacher_id` صحيح في جدول `groups` (من جدول `teachers` وليس `users`)
2. المعلم له سجل في جدول `teachers` مع `user_id` صحيح

---

## 🔴 المشكلة 7: حالة الحضور تُحفظ بشكل خاطئ

### الوصف
عند تسجيل الطالب كـ "غائب بعذر" (excused)، يظهر في تطبيق الطالب كـ "متأخر" (late).

### نتيجة الفحص
```
calculate_detailed_attendance_rate:
   ├─ present: 0
   ├─ absent: 0
   ├─ late: 1       ← يجب أن يكون 0
   ├─ excused: 0    ← يجب أن يكون 1
```

### السبب الجذري
تطبيق الإدارة يُرسل قيمة `status` خاطئة عند حفظ الحضور.

### الحل المطلوب
التأكد من إرسال القيمة الصحيحة:
```dart
// القيم المتوقعة: 'present', 'absent', 'late', 'excused'
await supabase.from('attendance').insert({
  'status': 'excused',  // وليس 'late'
  // ...
});
```

---

## 🔴 المشكلة 8: تباين نسبة الحضور بين الشاشات

### الوصف
- **الداشبورد:** يظهر 0% (أو فارغ)
- **شاشة الحضور:** يظهر 100%

### السبب الجذري
- الداشبورد يأخذ `attendance_rate` من RPC `get_student_centers_detailed` (يُرجع `null`)
- شاشة الحضور تستخدم RPC `calculate_detailed_attendance_rate` (يُرجع 100%)

### الحل المطلوب
تحديث RPC `get_student_centers_detailed` لحساب `attendance_rate` بشكل صحيح:
```sql
-- بدلاً من null، يجب حساب النسبة الفعلية
SELECT 
  ...,
  (SELECT calculate_attendance_rate(auth.uid(), c.id, NULL, NULL)) as attendance_rate
FROM centers c
...
```

---

## 📊 جدول ملخص الإصلاحات المطلوبة

| المشكلة | الأولوية | المسؤول | الحالة |
|---------|----------|---------|--------|
| تعبئة بيانات الطالب | 🔴 عالية | تطبيق الإدارة | **يتطلب إصلاح** |
| البريد الإلكتروني | 🟡 متوسطة | تطبيق الإدارة | **يتطلب إصلاح** |
| سجلات المدفوعات | 🔴 عالية | تطبيق الإدارة | **يتطلب إصلاح** |
| ظهور المعلمين للرسائل | 🔴 عالية | RPC + تطبيق الإدارة | **يتطلب إصلاح** |
| حالة الحضور الخاطئة | 🔴 عالية | تطبيق الإدارة | **يتطلب إصلاح** |
| تباين نسبة الحضور | 🔴 عالية | RPC | **يتطلب إصلاح** |
| ربط المعلم | 🟢 منخفضة | ✅ تم حله | مُصلح في RPC |
| ترتيب الأيام | 🟢 منخفضة | ✅ تم حله | مُصلح في الكود |


---

## 🧪 اختبار الإصلاحات

بعد تطبيق الإصلاحات، يمكن التحقق بهذا الـ SQL:

```sql
-- التحقق من بيانات الطالب
SELECT 
  s.full_name,
  s.student_code,
  s.academic_year,
  s.school_name,
  s.email,
  s.phone
FROM students s
WHERE s.user_id = 'USER_ID_HERE';

-- التحقق من ربط المعلم بالمجموعات
SELECT 
  g.group_name,
  g.teacher_id,
  t.id as teacher_table_id,
  u.full_name as teacher_name
FROM groups g
LEFT JOIN teachers t ON g.teacher_id = t.id
LEFT JOIN users u ON t.user_id = u.id;
```

---

## 📞 للتواصل

إذا كانت هناك استفسارات حول هذا التقرير، يرجى التواصل.

---

*تاريخ التقرير: 2026-01-09*