# سياسات RLS المقترحة

- المبدأ العام: كل صف مرتبط بـ `center_id` يجب أن يُتاح فقط لمستخدمي نفس السنتر، باستثناء دور Super Admin الذي يملك وصولاً شاملاً.
- الربط بالهوية: جدول `profiles` يحدد `user_type` و `center_id` (إن وجد)، وتُستخدم هذه القيم في السياسات.

## الطلاب (students) + ربط الطلاب بالمراكز (student_centers)
- SELECT: مستخدم لديه `user_type` ضمن {center_admin, staff, accountant, coordinator, teacher} وبـ `center_id` يساوي صفوفه في `student_centers.center_id`.
- INSERT/UPDATE/DELETE: فقط {center_admin, staff, accountant, coordinator} وعلى نفس `center_id`.

## المواد/الدورات (courses)
- SELECT: أي مستخدم مرتبط بنفس `center_id`.
- INSERT/UPDATE/DELETE: {center_admin, coordinator} على نفس `center_id`.

## الجداول (classrooms)
- SELECT: أي مستخدم مرتبط بنفس `center_id`.
- INSERT/UPDATE/DELETE: {center_admin, staff} على نفس `center_id`.

## الجداول الزمنية (schedules)
- SELECT: أي مستخدم مرتبط بنفس `center_id`.
- INSERT/UPDATE/DELETE: {center_admin, coordinator} على نفس `center_id`.

## الحضور (attendance)
- SELECT: أي مستخدم مرتبط بنفس `center_id`.
- INSERT: {center_admin, teacher, staff}.
- UPDATE/DELETE: {center_admin, staff}.

## المدفوعات (payments)
- SELECT: {center_admin, accountant, staff} على نفس `center_id`.
- INSERT/UPDATE/DELETE: {center_admin, accountant} فقط.

## الدرجات (grades)
- SELECT: {center_admin, teacher, staff} على نفس `center_id`.
- INSERT/UPDATE: {teacher, center_admin}.
- DELETE: {center_admin} فقط.

## المعلمون (teachers) + teacher_centers
- SELECT: أي مستخدم مرتبط بنفس `center_id`.
- INSERT/UPDATE/DELETE: {center_admin, coordinator} على نفس `center_id`.

ملاحظة: يجب تفعيل RLS لكل جدول وإضافة السياسات بما يحقق ما سبق، مع سياسة استثناء لدور Super Admin.