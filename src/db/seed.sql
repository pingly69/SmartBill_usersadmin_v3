-- Seed Data for SmartBill Users Admin Testing
DELETE FROM audit_logs;
DELETE FROM users_profile;

-- 1. Registered Petty Cash Controller (Holding cash fund)
INSERT INTO users_profile (
  users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
  'USR-0001',
  '',
  'สุภาพร บุญมา (ผู้ถือเงินสดย่อย)',
  'U1000000000000000000000000000001',
  'Supaporn.B',
  '00101',
  'supaporn@company.com',
  10000.00,
  '',
  'Y',
  '["PC01","PC02"]',
  '["คุมวงเงินสด"]'
);

-- 2. Registered Approver (Manager authorized to approve petty cash compensation)
INSERT INTO users_profile (
  users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
  'USR-0002',
  '',
  'มนตรี เกียรติสกุล (ผู้จัดการฝ่าย)',
  'U2000000000000000000000000000002',
  'Montri.K',
  '00045',
  'montri@company.com',
  0.00,
  '',
  'Y',
  '["PC01","PC02","ADMIN"]',
  '["อนุมัติวงเงินสด"]'
);

-- 3. Pending User 1 (Ready to test Registration with PIN 123456)
INSERT INTO users_profile (
  users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
  'USR-0003',
  '123456',
  'สมชาย ใจดี',
  '',
  '',
  '00521',
  'somchai@company.com',
  5000.00,
  '',
  'N',
  '["PC01"]',
  '["คุมวงเงินสด"]'
);

-- 4. Pending User 2 (Ready to test Registration with PIN 654321)
INSERT INTO users_profile (
  users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
  'USR-0004',
  '654321',
  'กานดา รัตนโชติ',
  '',
  '',
  '00522',
  'kanda@company.com',
  15000.00,
  '',
  'N',
  '["PC01"]',
  '["อนุมัติวงเงินสด"]'
);

-- Initial Audit Log
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('SYSTEM_INIT', 'SYSTEM', 'DATABASE_SEED', '{"message":"Initialized seed users"}');
