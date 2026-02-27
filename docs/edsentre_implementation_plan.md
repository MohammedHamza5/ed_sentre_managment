# خطة تنفيذ شاملة لنظام EdSentre

هذه الوثيقة تقدم خطة تنفيذ عملية ومفصلة لبناء نظام إدارة المراكز التعليمية EdSentre بشكل متكامل، استناداً إلى:
- نظرة عامة على النظام ومتطلباته (Super Admin، Center Management، Teacher/Student/Parent Apps)
- البنية الحالية للمشروع (Flutter Desktop/Mobile، Supabase PostgreSQL/Auth/Storage/Realtime/Edge Functions)
- الكود المتاح في المشروع (GoRouter، Bloc، Drift، Supabase integration)
- مخطط قاعدة البيانات في Supabase (full_schema.sql)

---

## 1) الملخص التنفيذي

EdSentre منصة لإدارة المراكز التعليمية تدعم تعدد المراكز والفروع، مع إدارة مركزية (Super Admin)، إدارة لكل مركز (Center Management)، وتطبيقات جوال لكل دور (Teacher، Student، Parent). النظام يستهدف بناء تجربة عربية كاملة (RTL) قابلة للتوسع، آمنة، وذات أداء عالٍ، مع دعم Offline-first عبر قاعدة محلية (Drift) ومزامنة مع Supabase.

---

## 2) الأهداف الرئيسية

1. مواءمة المخطط بين القاعدة المحلية Drift وسكيما Supabase لضمان توافق البيانات ثنائياً.
2. دعم Multi-tenancy فعّال: مستخدم/طالب/معلم يمكنهم الانتماء لعدة مراكز، وكل مركز له فروع وأدوار.
3. تطبيق RLS وسياسات أمان صارمة في Supabase، مع أدوار وصلاحيات واضحة لكل تطبيق/دور.
4. تنفيذ استراتيجية Offline-first مع SyncService لمزامنة البيانات وحل التعارضات.
5. بناء واجهة مستخدم عربية مريحة، Responsive، مع دعم الإنجليزية، وإدارة ثيمات ولغات وRTL.
6. تحسين الأداء عبر Pagination، Indexes، Caching، والالتزام بأفضل ممارسات Flutter/Supabase.
7. تحسين قابلية الصيانة: طبقات واضحة (Domain/Data/Presentation)، تكامل موثّق، اختبارات شاملة، CI.

---

## 3) النطاق والتسليمات

- نطاق المرحلة الأولى: توحيد المخطط (Subjects vs Courses، Rooms، Sessions vs Schedules، Attendance، Payments، Grades)، وتصميم RLS الدور-المركز، وتهيئة طبقة مابين (DTO/Mappers).
- نطاق المرحلة الثانية: تنفيذ مزامنة Offline-first، إنشاء SyncService، وإضافة سياسات Edge Functions للمزامنة، والإشعارات.
- نطاق المرحلة الثالثة: تحسينات واجهة المستخدم، التقارير، والاختبارات الآلية والـ CI.
- نطاق المرحلة الرابعة: الأداء والتوسّع، الفهارس، الـ pagination، والتحسينات الأمنية المتقدمة (MFA، سجلات تدقيق موسعة).

التسليمات:
- وثائق: خارطة مخطط، سياسات RLS، مخطط المزامنة، API contracts، حافظة أخطاء مركزية.
- كود: طبقة DTO/Mappers، تحديث المستودعات، SyncService، تكامل Edge Functions، تحسينات UI/UX.
- اختبارات: وحدات لـ Bloc/Repositories، تكامل Supabase، اختبارات ترحيل Drift.
- CI: Flavors وبيئات dev/stage/prod، تكامل مع Supabase الاختبارية.

---

## 4) معمارية النظام

### 4.1 طبقة الواجهة (Flutter)
- Desktop: 
  - Super Admin: إدارة النظام الشاملة.
  - Center Management: إدارة الطلاب/المعلمين/الجدولة/الحضور/المدفوعات/التقارير.
- Mobile:
  - Teacher App: إدارة المواد، الواجبات، التقييم، حضور الطلاب، التواصل، تقارير أكاديمية.
  - Student App: عرض الجداول، الواجبات، الدرجات، الحضور، المواد التعليمية، الدفع.
  - Parent App: متابعة الأبناء، الحضور والدرجات، التواصل، الدفع، التقارير.

تقنيات رئيسية:
- GoRouter للتوجيه مع إعادة توجيه حسب المصادقة.
- flutter_bloc لإدارة الحالة لكل ميزة.
- Provider لـ SettingsProvider (موضوع/لغة/عملة).
- Drift كقاعدة محلية مع ترحيلات وإدارة جداول: Students/Teachers/Subjects/Rooms/Sessions/Payments/Attendance.
- Supabase Flutter للتكامل مع Auth، Database، Storage، Realtime.

### 4.2 طبقة البيانات
- واجهة مجردة IDataRepository مع تطبيقين:
  - LocalRepository (Drift).
  - RemoteRepository (Supabase).
- طبقة تحويل (DTO/Mappers) بين النماذج الدومينية والجداول البعيدة (مثل Course ↔ Subject).
- SyncService: مزامنة ثنائية الاتجاه، إدارة isSynced/updatedAt، حل التعارضات.

### 4.3 الباك-إند (Supabase)
- PostgreSQL بجداول متعددة تدعم Multi-tenancy:
  - centers، branches، center_users، roles، profiles
  - students، teachers، courses، schedules، attendance، payments، grades
  - ربط متعدد: student_centers، teacher_centers، student_courses
- Auth: تسجيل/دخول/خروج، MFA، استرجاع كلمة المرور، أدوار.
- Storage: ملفات وصور (profile_image، cv_file، attachments).
- Realtime: قنوات بث لتغييرات الحضور/المدفوعات/الجدولة.
- Edge Functions: منطق أعمال (حساب مدفوعات، إرسال إشعارات، تسوية حضور/تضارب جدول).

---

## 5) نموذج تعدد المراكز (Multi-tenancy Model)

- مركز (center) يمكن أن يحتوي عدة فروع (branch).
- المستخدم يمكن أن يمتلك عدة انتماءات (memberships) عبر center_users مع دور محدد.
- الطالب يمكن أن يكون مسجلاً في عدة مراكز (student_centers)، وكذلك المعلم (teacher_centers).
- المواد/الدورات يمكن ربطها بالمركز والفروع، والطالب يمكن أن يسجل في عدة دورات (student_courses).
- جميع العمليات يجب أن تتضمن center_id (وأحياناً branch_id) لتصفية البيانات والسيطرة عليها في RLS.

---

## 6) سياسات الأمان (RLS) والأدوار

- أدوار رئيسية:
  - super_admin: إدارة جميع المراكز والاشتراكات.
  - center_admin: إدارة مركز معيّن (وكافة فروعه).
  - accountant: إدارة المدفوعات والمصاريف والتقارير المالية.
  - academic_coordinator: إدارة الجدولة، القاعات، المواد، الحضور/الغياب.
  - teacher: صلاحيات مرتبطة بموادهم وجلساتهم.
  - student: صلاحيات الإطلاع على مواده وحضوره ومدفوعاته الخاصة.
  - parent: صلاحيات الإطلاع على أبناءه فقط.

- سياسات RLS:
  - لكل جدول RLS يقيّد الوصول بـ center_id/branch_id ودور المستخدم.
  - سياسات قراءة/كتابة منفصلة؛ القيود على التعديل والحذف حسب الدور.
  - مراعاة الجداول الوسيطة (student_courses، student_centers، teacher_centers).

---

## 7) مواءمة المخطط بين Drift و Supabase

- Subjects (محلي) ↔ Courses (Supabase):
  - توحيد التسمية واستخدام Course كاسم موحّد في البعيد، وإبقاء Subject كنموذج دوميني إن رغبت.
  - إنشاء CourseDTO و CourseMapper.

- Rooms:
  - محلياً موجود Rooms؛ يجب التأكد من وجود جدول rooms في Supabase.
  - في حال عدم وجوده، إضافة جدول rooms مع الحقول: id، number، name، capacity، equipment، status، center_id، branch_id، timestamps.

- Sessions (محلي) ↔ Schedules (Supabase):
  - توحيد التسمية: الاعتماد على schedules في Supabase، مع ربط subject/course، room، teacher، dayOfWeek، startTime، endTime، status.
  - إنشاء ScheduleDTO و ScheduleMapper.

- Attendance:
  - محلياً يتضمن studentId، sessionId، date، status، notes، checkIn/Out.
  - Supabase يجب أن يدعم center_id، schedule_id، recorded_by، recorded_at، updated_at، مع تحقق لقيم status.

- Payments:
  - توحيد الحقول: amount، type، date، description، student_id، center_id، branch_id، status إن وجد.
  - إنشاء PaymentDTO و PaymentMapper.

- Grades:
  - ربط بالطالب/المادة/الاختبار؛ تصميم DTO/Mapper؛ التحقق من تواجد جدول grades في Supabase.

- Many-to-Many:
  - student_subjects (محلي) ↔ student_courses (Supabase).
  - teacher_subjects (محلي) ↔ teacher_courses أو ربط teacher مع course عبر جدول وسيط.

---

## 8) استراتيجية المزامنة Offline-first

- حقول المزامنة: isSynced، updatedAt، version/revision.
- سياسة التعارض:
  - last-write-wins كافتراضي مع إمكانية تخصيص حسب الكيان.
  - سجلات تعارض تُكتب في جدول محلي مع إشعار للمستخدم.
- تدفقات:
  - Pull: جلب تغييرات Supabase منذ آخر updatedAt.
  - Push: رفع التعديلات المحلية للمركز/الفرع المناسب مع التحقق من RLS.
- جدولة:
  - مزامنة دورية وخلفية؛ مؤشر حالة الاتصال والمزامنة في AppShell.

---

## 9) خارطة طريق التنفيذ (Sprints)

### المرحلة 1 (الأسبوع 1-2): مواءمة المخطط وRLS
- مراجعة شاملة لـ full_schema.sql وتحديث/إضافة: rooms، توحيد schedules، تدقيق courses/grades.
- تصميم وتطبيق RLS للأدوار لكل جدول.
- إعداد DTO/Mappers: Course/Room/Schedule/Attendance/Payment/Grade.
- تحديث SupabaseRepository لاستخدام DTO/Mappers ولإدارة center_id/_currentCenterId بشكل موحّد.

### المرحلة 2 (الأسبوع 3-4): مزامنة Offline-first
- بناء SyncService: queue، conflict resolution، retry، backoff.
- تفعيل isSynced/updatedAt/version محلياً وبعيداً.
- Edge Functions: webhook-like لمعالجة تغييرات حيوية (حضور/المدفوعات/الجداول).

### المرحلة 3 (الأسبوع 5-6): تحسينات الواجهة والتجربة
- RTL وفحص شامل للتوافق، تحسين AppShell بالإشعارات والحالة.
- صفحات التقارير (المركزية والداخلية)، تحسين شاشات الطلاب/المعلمين/الحضور/المدفوعات.
- توحيد ErrorHandler وإشعارات المستخدم.

### المرحلة 4 (الأسبوع 7-8): الجودة والأداء
- اختبارات Bloc/Repository/Integration.
- CI مع Flavors dev/stage/prod، بيئة Supabase اختبارية.
- Pagination/Indexes/Caching وتحسين الاستعلامات محلياً وبعيداً.

---

## 10) معايير القبول (Acceptance Criteria)

- توحيد المخطط: جميع الكيانات الأساسية متوافقة (Subjects/Courses، Rooms، Schedules/Sessions، Attendance، Payments، Grades).
- RLS: اختبارات دورية تثبت أن كل دور له صلاحيات صحيحة، ولا وجود لتسريب بيانات.
- المزامنة: قدرة على العمل دون اتصال وإعادة مزامنة سليمة، مع حل تعارضات موثق.
- الواجهة: دعم RTL/EN، تصميم Responsive، تجربة سلسة.
- الأداء: معاملات كبيرة تعمل بكفاءة (آلاف المستخدمين)، زمن استجابة جيد.
- الاختبارات: تغطية معقولة للطبقات الأساسية، مرور CI بدون أخطاء.

---

## 11) المخاطر والتخفيف

- اختلاف المخطط محلي/بعيد: معالجة عبر طبقة DTO/Mappers وخارطة سكيما موحّدة.
- التعارضات في المزامنة: اعتماد سياسة واضحة وسجل تعارضات قابل للمراجعة.
- تعقيد RLS: توثيق سياسات مفصل واختبارات تكامل دورية.
- الأداء تحت الحمل: Pagination/Indexes وقياس/تحسين مستمر.

---

## 12) مؤشرات الأداء (KPIs)

- زمن المزامنة المتوسطة: < 3 ثوانٍ لتحديثات صغيرة.
- زمن تحميل القوائم: < 1 ثانية للنتائج المصفّحة (صفحة 20 عنصر).
- نسبة نجاح المزامنة: > 99% بدون تعارضات غير محلولة.
- معدل الأعطال: < 0.5% من العمليات اليومية.

---

## 13) معايير التنظيم والترميز

- بنية المجلدات: 
  - lib/core (constants, database, l10n, providers, routing, supabase, theme, utils)
  - lib/shared (data, models, widgets, mappers, dto)
  - lib/features (students, teachers, subjects/courses, rooms, schedule/sessions, attendance, payments, reports, notifications, settings, auth)
- توحيد أسماء الكيانات: Course/Subject، Schedule/Session وفق اعتمادنا النهائي.
- توحيد واجهات المستودعات: add/get/update/delete مع أخطاء من نوع Result/Either بدلاً من الاستثناءات غير المضبوطة.

---

## 14) الخطوات التالية (Next Actions)

1. تحديث خارطة السكيما (schema_map.md) لتوثيق مواءمة الكيانات بين Drift و Supabase، مع الحالات المخصصة لكل جدول.
2. إضافة طبقة DTO/Mappers:
   - shared/data/dto: CourseDto, RoomDto, ScheduleDto, AttendanceDto, PaymentDto, GradeDto
   - shared/data/mappers: course_mapper.dart, room_mapper.dart, schedule_mapper.dart, attendance_mapper.dart, payment_mapper.dart, grade_mapper.dart
3. تحديث SupabaseRepository لاستخدام DTO/Mappers، وضبط center_id/_currentCenterId بشكل موحّد، ومعالجة الجداول الوسيطة (student_courses، student_centers، teacher_centers).
4. تصميم أولي لسياسات RLS لكل جدول، وإضافة وثيقة تفصيلية في docs/rls_policies.md.
5. إنشاء هيكل SyncService وواجهة عمله (queue، conflict resolver، retry، backoff)، ووثيقة تصميم في docs/sync_design.md.

---

## 15) طلبات/قرارات مطلوبة

- اعتماد التسمية النهائية: هل نعتمد Courses كاسم موحّد بدلاً من Subjects في البعيد، مع الحفاظ على Subject في الدومين؟
- تأكيد وجود جدول rooms في Supabase أو إضافته.
- اعتماد سياسة التعارض الافتراضية (last-write-wins) أو تخصيصها لكل كيان.
- تحديد الأولويات في تنفيذ التطبيقات المحمولة بعد اكتمال إدارة مركزية سطح المكتب.

---