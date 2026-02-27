# 📱 دليل شامل لتطبيق الطالب - EdSentre Student App

هذا المستند يشرح بالتفصيل كل الميزات والوظائف التي يحتاجها تطبيق الطالب، ليفهمها الذكاء الاصطناعي الذي يطور تطبيق الطالب بشكل كامل.

---

## 🏗 بنية النظام الأساسية

### 1. هوية الطالب في النظام

الطالب له **ثلاثة مستويات** من البيانات:

| المستوى | الجدول | الوصف |
|---------|--------|-------|
| **المستخدم** | `auth.users` + `public.users` | حساب تسجيل الدخول (UUID من Supabase Auth) |
| **الطالب** | `students` | بيانات الطالب التفصيلية (اسم، هاتف، عنوان، مرحلة) |
| **التسجيل بالسنتر** | `student_enrollments` | ربط الطالب بالسنتر (center_id) |

### 2. كيفية التعرف على الطالب الحالي

```dart
// 1. الحصول على user_id من Supabase Auth
final userId = Supabase.instance.client.auth.currentUser?.id;

// 2. جلب enrollment الخاص بالمستخدم
final enrollment = await supabase
    .from('student_enrollments')
    .select('''
      *,
      students!inner(*)
    ''')
    .eq('student_user_id', userId)
    .eq('status', 'active')
    .single();

// 3. الآن يمكنك الوصول لـ:
final centerId = enrollment['center_id'];       // معرف السنتر
final studentId = enrollment['student_id'];     // معرف الطالب
final studentData = enrollment['students'];     // بيانات الطالب كاملة
```

---

## 🎯 الميزات الرئيسية للطالب

---

# ميزة 1: الملف الشخصي (Profile)

## الغرض
عرض وتعديل بيانات الطالب الأساسية.

## البيانات المطلوبة من جدول `students`:

| الحقل | النوع | الوصف |
|-------|------|-------|
| `id` | UUID | معرف الطالب |
| `full_name` | String | الاسم الكامل |
| `phone` | String | رقم الهاتف |
| `email` | String? | البريد الإلكتروني |
| `stage` | String | المرحلة الدراسية (1st Secondary, 2nd Secondary, 3rd Secondary) |
| `school` | String? | اسم المدرسة |
| `address` | String? | العنوان |
| `birth_date` | Date? | تاريخ الميلاد |
| `student_code` | String | كود الطالب الفريد |
| `created_at` | DateTime | تاريخ التسجيل |

## كيفية الجلب:
```dart
final profile = await supabase
    .from('students')
    .select('*')
    .eq('id', studentId)
    .single();
```

## ما يظهر للطالب:
1. **رأس البطاقة**: صورة + اسم + مرحلة + كود الطالب
2. **بيانات شخصية**: هاتف، إيميل، عنوان، تاريخ ميلاد
3. **بيانات دراسية**: المدرسة، المرحلة، تاريخ التسجيل

---

# ميزة 2: الجدول الدراسي (Schedule)

## الغرض
عرض مواعيد الحصص الأسبوعية للطالب.

## ⚠️ مهم جداً: آلية الجدول

الجدول يأتي من **المجموعات** التي الطالب مسجل فيها:

```
الطالب ──► student_group_enrollments ──► groups ──► (day_of_week, start_time, end_time)
```

## البيانات المطلوبة:
```dart
final schedule = await supabase
    .from('student_group_enrollments')
    .select('''
      *,
      groups!student_group_enrollments_group_id_fkey (
        id,
        group_name,
        day_of_week,
        start_time,
        end_time,
        teacher_id,
        room_id,
        courses (
          id,
          name
        ),
        teachers (
          users (full_name)
        ),
        rooms (
          name,
          floor
        )
      )
    ''')
    .eq('student_id', studentId)
    .eq('status', 'active');
```

## هيكل عنصر الجدول:

| الحقل | المصدر | القيمة المتوقعة |
|-------|--------|-----------------|
| `day_of_week` | `groups.day_of_week` | 0-6 (السبت=0، الجمعة=6) |
| `start_time` | `groups.start_time` | "14:00" |
| `end_time` | `groups.end_time` | "15:30" |
| `subject_name` | `groups.courses.name` | "رياضيات" |
| `teacher_name` | `groups.teachers.users.full_name` | "أ. محمد" |
| `room_name` | `groups.rooms.name` | "قاعة 1" |
| `group_name` | `groups.group_name` | "رياضيات - 3ث - السبت" |

## ما يظهر للطالب:
- جدول أسبوعي بالأيام (السبت - الجمعة)
- لكل يوم: الحصص مرتبة بالوقت
- كل حصة تظهر: المادة + المعلم + الوقت + القاعة

## ترجمة أيام الأسبوع:
```dart
const dayNames = {
  0: 'السبت',
  1: 'الأحد',
  2: 'الإثنين',
  3: 'الثلاثاء',
  4: 'الأربعاء',
  5: 'الخميس',
  6: 'الجمعة',
};
```

---

# ميزة 3: المواد الدراسية (Subjects)

## الغرض
عرض المواد المسجل بها الطالب مع تفاصيلها.

## هناك طريقتان للحصول على المواد:

### الطريقة 1: عبر student_courses (إذا كان الطالب مسجل مباشرة بالمادة)
```dart
final subjects = await supabase
    .from('student_courses')
    .select('''
      *,
      courses (
        id,
        name,
        code,
        fee
      )
    ''')
    .eq('student_id', studentId);
```

### الطريقة 2: عبر المجموعات (الأكثر استخداماً)
```dart
final enrollments = await supabase
    .from('student_group_enrollments')
    .select('''
      groups!inner (
        courses (
          id,
          name,
          code,
          fee,
          teacher_courses (
            teachers (
              users (full_name)
            )
          )
        )
      )
    ''')
    .eq('student_id', studentId)
    .eq('status', 'active');

// استخراج المواد الفريدة
final uniqueSubjects = <String, Map>{};
for (final e in enrollments) {
  final course = e['groups']?['courses'];
  if (course != null) {
    uniqueSubjects[course['id']] = course;
  }
}
```

## ما يظهر للطالب:
- قائمة بالمواد المسجل بها
- لكل مادة: الاسم + المعلم + الرسوم الشهرية
- عدد الحصص في الأسبوع

---

# ميزة 4: سجل الحضور (Attendance)

## الغرض
عرض سجل حضور الطالب مع الإحصائيات.

## جلب سجل الحضور:
```dart
final attendance = await supabase
    .from('attendance')
    .select('''
      id,
      date,
      status,
      notes,
      check_in_time,
      groups (
        group_name,
        courses (name)
      )
    ''')
    .eq('student_id', studentId)
    .order('date', ascending: false)
    .limit(30);  // آخر 30 سجل
```

## حالات الحضور:
| القيمة | المعنى | اللون |
|--------|--------|-------|
| `present` | حاضر | أخضر |
| `absent` | غائب | أحمر |
| `late` | متأخر | برتقالي |
| `excused` | معذور | أزرق |

## حساب الإحصائيات:
```dart
int present = records.where((r) => r['status'] == 'present').length;
int absent = records.where((r) => r['status'] == 'absent').length;
int late = records.where((r) => r['status'] == 'late').length;
int total = records.length;

double attendanceRate = total > 0 ? (present + late) / total * 100 : 0;
```

## ما يظهر للطالب:
1. **إحصائيات عامة**: نسبة الحضور، عدد الغيابات
2. **تفصيل حسب المادة**: حضور كل مادة
3. **سجل تفصيلي**: آخر 30 يوم مع الحالة والملاحظات

---

# ميزة 5: المدفوعات والفواتير (Payments)

## الغرض
عرض فواتير الطالب وحالة الدفع.

## جلب المدفوعات:
```dart
final payments = await supabase
    .from('payments')
    .select('''
      id,
      amount,
      paid_amount,
      status,
      payment_method,
      due_date,
      paid_date,
      month_year,
      receipt_number,
      notes,
      created_at
    ''')
    .eq('student_id', studentId)
    .order('created_at', ascending: false);
```

## حالات الدفع:
| القيمة | المعنى | اللون | الإجراء |
|--------|--------|-------|---------|
| `paid` | مدفوع | أخضر | لا شيء |
| `pending` | معلق | برتقالي | يجب الدفع |
| `partial` | جزئي | أصفر | إكمال الدفع |
| `overdue` | متأخر | أحمر | يجب الدفع فوراً |

## طرق الدفع:
| القيمة | المعنى |
|--------|--------|
| `cash` | نقدي |
| `vodafone_cash` | فودافون كاش |
| `bank_transfer` | تحويل بنكي |
| `instapay` | إنستا باي |

## حساب المتأخرات:
```dart
final overdue = payments.where((p) {
  if (p['status'] == 'paid') return false;
  final dueDate = DateTime.parse(p['due_date']);
  return dueDate.isBefore(DateTime.now());
}).toList();

double totalOverdue = overdue.fold(0.0, (sum, p) => 
  sum + (p['amount'] - (p['paid_amount'] ?? 0))
);
```

## ما يظهر للطالب:
1. **ملخص المالية**: إجمالي المدفوع، المتبقي، المتأخرات
2. **قائمة الفواتير**: لكل شهر مع الحالة
3. **تفاصيل كل فاتورة**: المبلغ، تاريخ الاستحقاق، رقم الإيصال

---

# ميزة 6: الإشعارات (Notifications)

## الغرض
إرسال تنبيهات للطالب عن أحداث مهمة.

## جلب الإشعارات:
```dart
final notifications = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', userId)  // أو student_id
    .order('created_at', ascending: false)
    .limit(50);
```

## أنواع الإشعارات:
| النوع | الوصف | المحتوى |
|-------|-------|---------|
| `payment_reminder` | تذكير بالدفع | "موعد دفع شهر يناير" |
| `attendance_alert` | تنبيه غياب | "لديك 3 غيابات متتالية" |
| `schedule_change` | تغيير موعد | "تم تغيير موعد حصة الرياضيات" |
| `general` | عام | رسالة من الإدارة |

## هيكل الإشعار:
```json
{
  "id": "uuid",
  "title": "تذكير بالدفع",
  "message": "يرجى سداد مصروفات شهر يناير",
  "type": "payment_reminder",
  "is_read": false,
  "action_url": "/payments",
  "created_at": "2026-01-09T10:00:00Z"
}
```

## تحديث حالة القراءة:
```dart
await supabase
    .from('notifications')
    .update({'is_read': true})
    .eq('id', notificationId);
```

---

# ميزة 7: المجموعات (Groups)

## الغرض
عرض المجموعات الدراسية المسجل بها الطالب.

## جلب مجموعات الطالب:
```dart
final groups = await supabase
    .from('student_group_enrollments')
    .select('''
      enrollment_date,
      status,
      groups!student_group_enrollments_group_id_fkey (
        id,
        group_name,
        max_students,
        monthly_fee,
        day_of_week,
        start_time,
        end_time,
        is_active,
        courses (name),
        teachers (
          users (full_name)
        )
      )
    ''')
    .eq('student_id', studentId)
    .eq('status', 'active');
```

## ما يظهر للطالب:
- اسم المجموعة
- المادة والمعلم
- الموعد الأسبوعي
- الرسوم الشهرية
- تاريخ الالتحاق

---

# ميزة 8: معلومات السنتر (Center Info)

## الغرض
عرض معلومات التواصل مع السنتر.

## جلب بيانات السنتر:
```dart
final center = await supabase
    .from('centers')
    .select('*')
    .eq('id', centerId)
    .single();
```

## البيانات المتاحة:
| الحقل | الوصف |
|-------|-------|
| `name` | اسم السنتر |
| `phone` | رقم الهاتف |
| `address` | العنوان |
| `email` | البريد الإلكتروني |
| `logo_url` | شعار السنتر |
| `working_hours` | ساعات العمل |

---

## 🔐 سياسات الوصول (RLS)

### السياسات المطلوبة لتطبيق الطالب:

```sql
-- الطالب يقرأ بياناته فقط
CREATE POLICY "students_read_own" ON students FOR SELECT
USING (
  id IN (
    SELECT student_id FROM student_enrollments 
    WHERE student_user_id = auth.uid()
  )
);

-- الطالب يقرأ حضوره فقط
CREATE POLICY "attendance_read_own" ON attendance FOR SELECT
USING (
  student_id IN (
    SELECT student_id FROM student_enrollments 
    WHERE student_user_id = auth.uid()
  )
);

-- الطالب يقرأ مدفوعاته فقط
CREATE POLICY "payments_read_own" ON payments FOR SELECT
USING (
  student_id IN (
    SELECT student_id FROM student_enrollments 
    WHERE student_user_id = auth.uid()
  )
);

-- الطالب يقرأ إشعاراته فقط
CREATE POLICY "notifications_read_own" ON notifications FOR SELECT
USING (user_id = auth.uid());
```

---

## 📊 ملخص الجداول والعلاقات

```
auth.users (login) ─────────────────────┐
      │ [user_id]                       │
      ▼                                 ▼
    users ─────────────────────► student_enrollments
                                        │
                                        │ [student_id, center_id]
                                        ▼
centers ◄─────────────────────────── students
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
          student_groups       student_courses        attendance
                │                      │                   │
                ▼                      ▼                   ▼
             groups ──────────────► courses          (سجلات)
                │                      │
                ▼                      ▼
             rooms              teacher_courses
                                       │
                                       ▼
                                   teachers
        
        payments ◄──── [student_id] ────► notifications
```

---

## ⚠️ أخطاء شائعة وحلولها

### 1. لا تظهر بيانات الطالب
**السبب**: الطالب غير مسجل في `student_enrollments`
**التحقق**:
```dart
final hasEnrollment = await supabase
    .from('student_enrollments')
    .select('id')
    .eq('student_user_id', userId)
    .maybeSingle();
// إذا null = الطالب غير مسجل
```

### 2. لا يظهر الجدول الدراسي
**السبب**: الطالب غير مسجل في أي مجموعة (`student_group_enrollments`)
**الحل**: يجب تسجيل الطالب في مجموعة من تطبيق الإدارة

### 3. لا تظهر المواد
**السبب**: إما عدم وجود `student_courses` أو عدم وجود مجموعات
**الحل**: استخدم الطريقة البديلة عبر المجموعات

### 4. خطأ RLS forbidden
**السبب**: سياسات RLS لا تسمح للطالب بالوصول
**الحل**: تأكد من وجود السياسات أعلاه

---

## 🔄 دورة حياة الطالب في النظام

```
1. إنشاء حساب (auth.users)
       │
       ▼
2. إنشاء student + student_enrollment (من تطبيق الإدارة)
       │  ┌──► يحصل على invitation_code
       ▼  │
3. تفعيل الحساب (ربط student_user_id بـ auth.uid)
       │
       ▼
4. تسجيل في مجموعات (student_group_enrollments)
       │
       ▼
5. يبدأ الاستخدام:
   - يرى جدوله
   - يرى حضوره
   - يرى مدفوعاته
   - يستقبل إشعارات
```

---

## 📱 شاشات التطبيق المقترحة

| الشاشة | المحتوى | البيانات |
|--------|---------|----------|
| **الرئيسية** | ملخص سريع | الحصة القادمة + إشعارات جديدة + حالة الدفع |
| **الجدول** | أسبوعي/يومي | المجموعات مع الأوقات |
| **المواد** | قائمة المواد | المعلم + عدد الحصص |
| **الحضور** | إحصائيات + سجل | نسبة الحضور + التفاصيل |
| **المدفوعات** | الفواتير | المدفوع + المتبقي + المتأخر |
| **الإشعارات** | التنبيهات | كل الإشعارات |
| **الملف الشخصي** | البيانات | معلومات الطالب |
| **الإعدادات** | تفضيلات | اللغة + الوضع الليلي + الإشعارات |

---

*آخر تحديث: 2026-01-09*
