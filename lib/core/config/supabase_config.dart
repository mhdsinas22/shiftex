class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hefscvlbskukbnigrbcz.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlZnNjdmxic2t1a2JuaWdyYmN6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3MzU0NjcsImV4cCI6MjExMDMxMTQ2N30.F9BxgA14zLQhnqwJm9q_AZkAULYN3CVHMLGejoZ5Bz0',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Vy8b1qySx0h5GCSY_Jt1_A_0rQOmV4T',
  );
}
