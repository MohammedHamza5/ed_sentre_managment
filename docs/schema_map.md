## Schema mapping (app vs Supabase)

- **Source of truth**: Supabase.
- **Students**: `students` + `student_centers` (status/grade scoped by center).
- **Courses/Subjects**: `courses` table (app domain “subjects”).
- **Schedule**: `schedules` with `course_id`, `teacher_id`, `classroom_id`.
- **Attendance**: `attendance` links `center_id`, `student_id`, `schedule_id`.
- **Payments**: `payments` links `center_id`, optional `student_id`.
- **Missing table noted in code**: `student_courses`.
  - Repo now falls back if `student_courses` is absent; to fully enable many-to-many enrollment, add that table or replace with existing relation and update mappings.

### Repository behavior
- `SupabaseRepository.getStudents()` tries `student_courses` and falls back to students + centers only.
- Add/update student links use best-effort insert/delete on `student_courses`; failures are swallowed if table is absent.

