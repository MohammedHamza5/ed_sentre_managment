## RLS quick checklist (Supabase)

- Ensure RLS is **enabled** on: `students`, `student_centers`, `attendance`, `payments`, `schedules`, `courses`, `user_centers`.
- Suggested policy shape (example, adjust roles):
  - Select/update/delete only when `center_id` matches a center the user belongs to via `user_centers`.
  - Insert only when the user has `role IN ('center_admin','admin')` for the target `center_id`.
  - Attendance/Payments: allow teachers to insert for students in their center; forbid cross-center access.
  - Storage objects (if used): scope bucket/folder per center_id.
- Rotate the leaked anon key after enabling RLS to avoid abuse.
- Test policies with `supabase-js`/`curl` using anon key to confirm least-privilege.

