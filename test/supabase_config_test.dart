import 'package:flutter_test/flutter_test.dart';
import 'package:ed_sentre/core/supabase/supabase_config.dart';

void main() {
  test('SupabaseConfig.ensureConfigured throws when env is missing', () {
    expect(
      () => SupabaseConfig.ensureConfigured(),
      throwsA(isA<StateError>()),
    );
  });
}



