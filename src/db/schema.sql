-- =============================================================================
-- Migration DDL: SmartBill Users Administration System (Unified Architecture)
-- Target: Cloudflare D1 (SQLite Engine)
-- Reference: skills/new_users_profile_and_approve.txt & skills/MIGRATION_CLOUDFLARE_D1_R2_SPEC.md
-- =============================================================================

PRAGMA foreign_keys = ON;

-- 1. Table: users_profile (Unified Single Source of Truth)
CREATE TABLE IF NOT EXISTS users_profile (
  -- Column A: Primary Key (Unique string e.g. 'USR-0001' or nanoid)
  users_id     TEXT        NOT NULL PRIMARY KEY,
  
  -- Column B: Password / Temporary 6-digit PIN
  password     TEXT        NOT NULL DEFAULT '',
  
  -- Column C: Full Name (Thai/English) - requester_name (aligned with Cloud D1 IMG_DB)
  requester_name TEXT        NOT NULL DEFAULT '',
  
  -- Column D: LINE UID (Optional from LINE LIFF, e.g. 'U1234567890...')
  line_uid     TEXT        NULL DEFAULT '',

  -- Column E: LINE Display Name
  display_name TEXT        NULL DEFAULT '',
  
  -- Column F: Employee Number (Preserves leading zeros e.g. '00412')
  emp_no       TEXT        NULL DEFAULT '',
  
  -- Column G: Email
  email        TEXT        NULL DEFAULT '',
  
  -- Column H: Petty Cash Limit (THB >= 0)
  pc_limit     REAL        NOT NULL DEFAULT 0.00 CHECK (pc_limit >= 0),
  
  -- Column I: Avatar URL
  avatar_url   TEXT        NULL DEFAULT '',

  -- Column J: Account Status ('Y' = Active/Registered, 'N' = Inactive/Pending PIN)
  active       TEXT        NOT NULL DEFAULT 'N' CHECK (active IN ('Y', 'N')),
  
  -- Column K: Screen Authorization Tags (JSON Array e.g. '["PC01"]')
  screen_tags  TEXT        NOT NULL DEFAULT '[]',
  
  -- Column L: Approver Tags (JSON Array e.g. '["คุมวงเงินสด","อนุมัติวงเงินสด"]')
  approve_tags TEXT        NOT NULL DEFAULT '[]',
  
  -- Audit fields
  created_at   TEXT        NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT        NOT NULL DEFAULT (datetime('now'))
);

-- Index for O(1) LINE UID lookup (Partial unique index allows multiple empty line_uids)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_profile_line_uid
  ON users_profile (line_uid)
  WHERE line_uid IS NOT NULL AND line_uid != '';

-- Index for Active status
CREATE INDEX IF NOT EXISTS idx_users_profile_active
  ON users_profile (active);

-- Index for Case-Insensitive Name search
CREATE INDEX IF NOT EXISTS idx_users_profile_requester_name
  ON users_profile (requester_name COLLATE NOCASE);

-- Index for Employee Number
CREATE INDEX IF NOT EXISTS idx_users_profile_emp_no
  ON users_profile (emp_no);

-- 2. Table: audit_logs
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

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs (target_identifier);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);

-- 3. Trigger for automated updated_at
CREATE TRIGGER IF NOT EXISTS trg_users_profile_updated_at
AFTER UPDATE ON users_profile
FOR EACH ROW
BEGIN
    UPDATE users_profile SET updated_at = datetime('now') WHERE users_id = OLD.users_id;
END;
