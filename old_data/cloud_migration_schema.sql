-- =============================================================================
-- SmartBill Cloud Migration Step 1: Safe Schema Expansion (IMG_DB)
-- Target: Cloudflare D1 (Database: IMG_DB)
-- Purpose: ขยายโครงสร้างตาราง users_profile บน Cloud ให้รองรับ SmartBill
-- Safety: Non-destructive In-Place Alter (ไม่กระทบข้อมูลรถ, พนักงาน, หรือประวัติเดิม)
-- =============================================================================

-- 1. Add SmartBill Extension Columns with Safe Defaults
ALTER TABLE users_profile ADD COLUMN users_id TEXT NOT NULL DEFAULT '';
ALTER TABLE users_profile ADD COLUMN password TEXT NOT NULL DEFAULT '';
ALTER TABLE users_profile ADD COLUMN display_name TEXT NOT NULL DEFAULT '';
ALTER TABLE users_profile ADD COLUMN email TEXT NOT NULL DEFAULT '';
ALTER TABLE users_profile ADD COLUMN pc_limit REAL NOT NULL DEFAULT 0.00;
ALTER TABLE users_profile ADD COLUMN avatar_url TEXT NOT NULL DEFAULT '';
ALTER TABLE users_profile ADD COLUMN active TEXT NOT NULL DEFAULT 'Y';
ALTER TABLE users_profile ADD COLUMN screen_tags TEXT NOT NULL DEFAULT '["PC01"]';
ALTER TABLE users_profile ADD COLUMN approve_tags TEXT NOT NULL DEFAULT '[]';

-- 2. Backfill users_id for existing rows that do not have one yet
UPDATE users_profile 
SET users_id = 'USR-' || upper(substr(replace(replace(line_uid, 'U', ''), '_', ''), 1, 8))
WHERE (users_id = '' OR users_id IS NULL) AND line_uid != '';

-- 3. Create Audit Logs Table for Enterprise Governance & Traceability
CREATE TABLE IF NOT EXISTS audit_logs (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    action            TEXT NOT NULL,
    performed_by      TEXT NOT NULL,
    target_identifier TEXT,
    details_json      TEXT,
    ip_address        TEXT,
    user_agent        TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 4. Create Performance Indexes for Fast Searching & Tag Filtering
CREATE INDEX IF NOT EXISTS idx_users_profile_requester_name
  ON users_profile (requester_name COLLATE NOCASE);

CREATE INDEX IF NOT EXISTS idx_users_profile_active
  ON users_profile (active);

CREATE INDEX IF NOT EXISTS idx_users_profile_emp_no
  ON users_profile (emp_no);

CREATE INDEX IF NOT EXISTS idx_users_profile_users_id
  ON users_profile (users_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action
  ON audit_logs (action);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON audit_logs (created_at);

-- 5. Record Initial Cloud Schema Migration Audit Entry
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('CLOUD_SCHEMA_EXPAND', 'MIGRATION_STEP_2', 'users_profile', '{"status":"SUCCESS","description":"Added SmartBill columns to IMG_DB.users_profile without data loss"}');
