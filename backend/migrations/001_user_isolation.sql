-- Database Migration: User Isolation and Data Integrity
-- Run this in your Supabase SQL Editor
-- Safe to run multiple times (idempotent)

-- ============================================
-- 1. CREATE JOBS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pdf_path TEXT NOT NULL,
  result_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'completed_with_warning', 'failed')),
  label_status TEXT CHECK (label_status IN ('success', 'failed', NULL)),
  error_message TEXT,
  label_warning TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Drop existing constraint if it exists (for idempotency)
ALTER TABLE jobs DROP CONSTRAINT IF EXISTS unique_user_job;

-- Add unique constraint
ALTER TABLE jobs ADD CONSTRAINT unique_user_job UNIQUE(user_id, id);

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_jobs_user_id;
DROP INDEX IF EXISTS idx_jobs_status;
DROP INDEX IF EXISTS idx_jobs_created_at;

-- Recreate indexes
CREATE INDEX idx_jobs_user_id ON jobs(user_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_created_at ON jobs(created_at DESC);

-- Enable RLS on jobs table
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS jobs_user_isolation ON jobs;
DROP POLICY IF EXISTS jobs_user_insert ON jobs;
DROP POLICY IF EXISTS jobs_user_update ON jobs;
DROP POLICY IF EXISTS jobs_user_delete ON jobs;

-- RLS Policy: Users can only see their own jobs
CREATE POLICY jobs_user_isolation ON jobs
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY jobs_user_insert ON jobs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY jobs_user_update ON jobs
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY jobs_user_delete ON jobs
  FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================
-- 2. CREATE SHEET_FILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS sheet_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  file_size_bytes BIGINT,
  status TEXT DEFAULT 'processing' CHECK (status IN ('processing', 'completed', 'failed', 'orphaned')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Drop existing constraint if it exists
ALTER TABLE sheet_files DROP CONSTRAINT IF EXISTS unique_user_job;

-- Add unique constraint
ALTER TABLE sheet_files ADD CONSTRAINT unique_user_job_files UNIQUE(user_id, job_id);

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_sheet_files_user_id;
DROP INDEX IF EXISTS idx_sheet_files_job_id;
DROP INDEX IF EXISTS idx_sheet_files_status;
DROP INDEX IF EXISTS idx_sheet_files_created_at;

-- Recreate indexes
CREATE INDEX idx_sheet_files_user_id ON sheet_files(user_id);
CREATE INDEX idx_sheet_files_job_id ON sheet_files(job_id);
CREATE INDEX idx_sheet_files_status ON sheet_files(status);
CREATE INDEX idx_sheet_files_created_at ON sheet_files(created_at DESC);

-- Enable RLS on sheet_files table
ALTER TABLE sheet_files ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS sheet_files_user_isolation ON sheet_files;
DROP POLICY IF EXISTS sheet_files_user_insert ON sheet_files;
DROP POLICY IF EXISTS sheet_files_user_update ON sheet_files;
DROP POLICY IF EXISTS sheet_files_user_delete ON sheet_files;

-- RLS Policies: Users can only see their own files
CREATE POLICY sheet_files_user_isolation ON sheet_files
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY sheet_files_user_insert ON sheet_files
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY sheet_files_user_update ON sheet_files
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY sheet_files_user_delete ON sheet_files
  FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================
-- 3. CREATE AUDIT LOG TABLE (Optional)
-- ============================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_audit_logs_user_id;
DROP INDEX IF EXISTS idx_audit_logs_created_at;

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);


-- ============================================
-- 4. CREATE VIEWS (Optional but useful)
-- ============================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS user_storage_usage CASCADE;
DROP VIEW IF EXISTS jobs_with_sheets CASCADE;

-- View for getting jobs with associated sheet files
CREATE OR REPLACE VIEW jobs_with_sheets AS
SELECT 
  j.id as job_id,
  j.user_id,
  j.pdf_path,
  j.result_url,
  j.status as job_status,
  j.error_message,
  j.created_at,
  COUNT(sf.id) as sheet_file_count
FROM jobs j
LEFT JOIN sheet_files sf ON j.id = sf.job_id
GROUP BY j.id, j.user_id, j.pdf_path, j.result_url, j.status, j.error_message, j.created_at;

-- View for user storage usage
CREATE OR REPLACE VIEW user_storage_usage AS
SELECT 
  user_id,
  COUNT(DISTINCT job_id) as total_jobs,
  COUNT(sf.id) as total_files,
  COALESCE(SUM(sf.file_size_bytes), 0) as total_storage_bytes,
  ROUND(COALESCE(SUM(sf.file_size_bytes), 0)::numeric / (1024 * 1024), 2) as total_storage_mb
FROM sheet_files sf
GROUP BY user_id;


-- ============================================
-- 5. STORAGE BUCKET POLICIES
-- ============================================

-- ⚠️ IMPORTANT: These policies MUST be added manually via Supabase Dashboard
-- They CANNOT be created via SQL
-- 
-- Steps:
-- 1. Go to Supabase Dashboard → Storage
-- 2. Click each bucket (sheet_data, pdf_uploads)
-- 3. Click "Policies" tab
-- 4. Create the policies below

-- ============================================
-- sheet_data BUCKET POLICIES
-- ============================================

-- POLICY 1: SELECT (Read own files)
-- Name: "Allow users to read own files"
-- Target roles: authenticated
-- Allowed operations: SELECT
-- Policy expression:
-- (bucket_id = 'sheet_data'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- POLICY 2: INSERT (Upload own files)
-- Name: "Allow users to upload own files"
-- Target roles: authenticated
-- Allowed operations: INSERT
-- Policy expression:
-- (bucket_id = 'sheet_data'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- POLICY 3: DELETE (Delete own files)
-- Name: "Allow users to delete own files"
-- Target roles: authenticated
-- Allowed operations: DELETE
-- Policy expression:
-- (bucket_id = 'sheet_data'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- ============================================
-- pdf_uploads BUCKET POLICIES
-- ============================================

-- POLICY 1: SELECT (Read own PDFs)
-- Name: "Allow users to read own PDFs"
-- Target roles: authenticated
-- Allowed operations: SELECT
-- Policy expression:
-- (bucket_id = 'pdf_uploads'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- POLICY 2: INSERT (Upload own PDFs)
-- Name: "Allow users to upload own PDFs"
-- Target roles: authenticated
-- Allowed operations: INSERT
-- Policy expression:
-- (bucket_id = 'pdf_uploads'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- POLICY 3: DELETE (Delete own PDFs)
-- Name: "Allow users to delete own PDFs"
-- Target roles: authenticated
-- Allowed operations: DELETE
-- Policy expression:
-- (bucket_id = 'pdf_uploads'::text) AND (auth.uid()::text = (storage.foldername[1])::text)

-- Migration completed successfully!
