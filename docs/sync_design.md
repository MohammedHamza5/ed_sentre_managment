# تصميم مزامنة Offline-First

## المبادئ
- المعرفات: استخدام UUID v4 لكل السجلات لضمان التوافق عبر الأجهزة.
- الطوابع الزمنية: حقلا `updated_at` و `isSynced` موجودان محلياً (Drift) ويجب مواءمتهما مع السحابة.
- المصدر الموثوق: Supabase هو المصدر النهائي للحقيقة؛ يُستخدم حل التعارضات باستراتيجية LWW (آخر تحديث يغلب).

## التدفق
1. إنشاء/تعديل محلياً: تُحدّث السجلات محلياً وتُعلّم بـ `isSynced=false`.
2. مزامنة مخرجات: تُرسل التغييرات إلى Supabase مع `updated_at` محلي.
3. مزامنة واردة: تُجلب السجلات من Supabase حسب `updated_at > آخر مزامنة`.
4. حل التعارضات:
   - إذا كان `updated_at_remote > updated_at_local`: نُحدّث المحلي بالقيمة البعيدة.
   - إذا كان `updated_at_local > updated_at_remote`: نُرفع المحلي إلى السحابة.
   - إذا تساويا: لا تغيير.
5. تأمين السياق: جميع الاستعلامات والإدراجات تُقيد بـ `center_id`.

## الجداول
- Students + student_centers: فصل بيانات الهوية عن حالة الطالب في السنتر.
- Courses/Subjects: `courses` تربط بـ `center_id`.
- Classrooms: `classrooms` تربط بـ `center_id`.
- Schedules: `schedules` تربط بـ `center_id`.
- Attendance/Payments/Grades: تربط بـ `center_id` مع حقول مرجعية مناسبة (`student_id`, `schedule_id`, إلخ).

## ملاحظات تنفيذية
- التعامل مع العلاقات many-to-many (مثل تسجيل الطالب في مادة): إضافة جدول `student_courses` أو إدراج علاقة بديلة، مع معالجة الأخطاء إن كان الجدول غير موجود.
- دفعات البيانات الكبيرة: استخدام pagination وlimit/offset أو keyset pagination عند الحاجة.