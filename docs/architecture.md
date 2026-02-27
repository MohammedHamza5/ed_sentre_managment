## App architecture (high level)

```mermaid
flowchart TD
  entry[main.dart] --> initSupabase[SupabaseClientManager.initialize]
  entry --> initDrift[AppDatabase]
  initDrift --> localRepo[DatabaseRepository]
  initSupabase --> cloudRepo[SupabaseRepository]
  entry --> authBloc[AuthBloc]
  authBloc --> router[AppRouter (GoRouter)]
  router --> shell[AppShell/Sidebar]
  shell --> features[Feature Screens]
```

## Data/DB relationships (simplified)

```mermaid
flowchart LR
  Centers -->|1..n| UserCenters
  Users -->|1..n| UserCenters
  Centers -->|1..n| StudentCenters
  Students -->|1..n| StudentCenters
  Centers -->|1..n| Schedules
  Courses -->|1..n| Schedules
  Teachers -->|1..n| Schedules
  Classrooms -->|1..n| Schedules
  Students -->|1..n| Attendance
  Schedules -->|0..n| Attendance
  Centers -->|1..n| Payments
  Students -->|0..n| Payments
```

## Setup notes

- Supply Supabase credentials via `--dart-define-from-file=supabase.env`.
- Local Drift schema lives in `lib/core/database/tables.dart`; Supabase schema is defined in `full_schema.sql`.
- Auth routing now listens to live Supabase auth changes via `_AuthRefreshNotifier`.

