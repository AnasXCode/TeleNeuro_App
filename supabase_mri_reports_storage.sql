-- =============================================================================
-- TeleNeuro — Storage policies for bucket id: mri-reports  (lowercase)
-- =============================================================================
-- Run in: Supabase Dashboard → SQL Editor
--
-- The REST API uses whatever is in storage.buckets.id (often lowercase).
-- If uploads return **404 Bucket not found**, your app bucket name does not match — run:
--   SELECT id, name FROM storage.buckets;
-- Then replace every 'mri-reports' below with your bucket's **id** exactly.
--
-- Why "anon"? Flutter uses the Supabase anon key only (Firebase Auth ≠ Supabase role).
-- =============================================================================

DROP POLICY IF EXISTS "anon_insert_mri_reports" ON storage.objects;
DROP POLICY IF EXISTS "anon_select_mri_reports" ON storage.objects;
DROP POLICY IF EXISTS "anon_update_mri_reports" ON storage.objects;

CREATE POLICY "anon_insert_mri_reports"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (bucket_id = 'mri-reports');

CREATE POLICY "anon_select_mri_reports"
ON storage.objects
FOR SELECT
TO anon
USING (bucket_id = 'mri-reports');

CREATE POLICY "anon_update_mri_reports"
ON storage.objects
FOR UPDATE
TO anon
USING (bucket_id = 'mri-reports')
WITH CHECK (bucket_id = 'mri-reports');
