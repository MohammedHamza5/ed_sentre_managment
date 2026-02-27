## DDL cleanup checklist

Targets to fix in the Supabase/Postgres schema dump before reapplying:

- Deduplicate FK constraints that appear twice:
  - `attendance`: center_id, schedule_id, student_id, recorded_by.
  - `student_centers`: center_id, student_id.
  - `payments`: center_id, student_id.
  - `schedules`: center_id, classroom_id, course_id, teacher_id.
- Unify ON DELETE behaviors:
  - Use `ON DELETE CASCADE` for center-owned data (`center_id`) and join tables.
  - Prefer `SET NULL` for optional relationships (teacher_id/classroom_id on schedules if not required).
  - Keep `attendance` and `payments` student links consistent (either CASCADE or SET NULL, choose one).
- Regenerate the dump after cleanup to avoid double FKs in future migrations.

