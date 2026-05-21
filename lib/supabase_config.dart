/// Supabase project credentials.
///
/// 1. Create a free project at https://supabase.com
/// 2. Open Project Settings -> API and copy:
///    - Project URL  -> [supabaseUrl]
///    - anon public key -> [supabaseAnonKey]
/// 3. Open Storage and create a public bucket called [supabaseBucket]
///    (or change the constant if you pick another name).
class SupabaseConfig {
  static const String supabaseUrl = 'https://lprztmszqvzewhogbkna.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxwcnp0bXN6cXZ6ZXdob2dia25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNDA5MTAsImV4cCI6MjA5MzkxNjkxMH0.XaQgc_SosEs1ZckXja1kSPjDepEaI4OTfsm5hZT17rU';

  /// Must match `storage.buckets.id` exactly (case-sensitive). Dashboard labels may be uppercase;
  /// the API almost always uses lowercase — **404 Bucket not found** means this string is wrong.
  /// Confirm with: `SELECT id FROM storage.buckets;` then paste that `id` here.
  static const String supabaseBucket = 'mri-reports';
}
