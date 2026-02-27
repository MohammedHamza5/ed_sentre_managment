## Runbook

### Env setup
- Copy `supabase.env.example` to `supabase.env` and fill `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Run with:  
  `flutter run --dart-define-from-file=supabase.env`

### Tests
- `flutter test`

### Windows sanity run
- From project root:  
  `flutter run -d windows`
- If LNK1168/INSTALL errors, close running exe, remove `build/windows`, then `flutter clean`, `flutter pub get`, and retry.

### Notes
- Supabase configs must be env-driven (no hardcoded keys).
- See `docs/schema_map.md` for schema alignment and `docs/rls_checklist.md` for RLS guidance.

