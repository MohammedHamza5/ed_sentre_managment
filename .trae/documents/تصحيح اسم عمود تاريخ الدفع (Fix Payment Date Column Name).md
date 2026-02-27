لقد قمت بتحليل الخطأ الجديد:
`column payments.paid_date does not exist`

هذا يعني أن العمود `paid_date` غير موجود في جدول `payments`، وأن الاسم الصحيح له هو `payment_date` (بناءً على ملف `full_backup.sql` الذي يظهر `p.payment_date::TIMESTAMPTZ as paid_at` في إحدى الدوال).

في ملف الـ Backup، جدول `payments` غير معرف بوضوح `CREATE TABLE` في الأجزاء التي قرأتها، لكن الدوال تشير إلى `payment_date`. بينما في الكود الحالي (`PaymentModel`) نحن نستخدم `paidDate`.

### خطة الإصلاح (The Fix Plan):
سأقوم بتعديل ملف `PaymentsRemoteSource` لاستخدام اسم العمود الصحيح في الاستعلامات.

1.  **تعديل `getPaymentsByMonth`:** استبدال `.gte('paid_date', ...)` بـ `.gte('payment_date', ...)` (أو الاسم الصحيح الذي سأتحقق منه الآن).
2.  **التحقق من `created_at`:** في بعض الأنظمة يتم استخدام `created_at` كتاريخ دفع افتراضي إذا لم يوجد عمود مخصص.

لكن، بالنظر إلى دالة `get_student_payments` في قاعدة البيانات (التي قرأناها سابقاً)، نجد السطر:
`p.payment_date::TIMESTAMPTZ as paid_at`

إذن اسم العمود في قاعدة البيانات هو **`payment_date`** وليس `paid_date`.

سأقوم بتحديث الكود في `PaymentsRemoteSource` لاستخدام `payment_date`.

**هل أبدأ بالتنفيذ؟**
