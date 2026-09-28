-- =============================================================================
-- SmartBill Cloud Migration: Merged Users & Approvers for Cloud D1 (IMG_DB)
-- Generated at: openpyxl ETL Runner
-- Total Unified Users: 16
-- Target Table: users_profile in Cloudflare D1 (IMG_DB)
-- Safety Guarantee: Existing car_no, group_car, and timestamps are NOT overwritten!
-- Strategy: UPSERT via ON CONFLICT(line_uid) DO UPDATE
-- =============================================================================

PRAGMA foreign_keys = ON;

-- [01] ศิริลักษณ์ ตรียัง(ฟ้า) (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U287b8987ec1a3d3f1c73f56bd88814ea', 'ศิริลักษณ์ ตรียัง(ฟ้า)', 'USR-MIG-0001', '', 'ศิริลักษณ์ ตรียัง', '', '', 30000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [02] อนุชา สารพันธ์ (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'Ufb494b7e68ed4b72df584a204146fafd', 'อนุชา สารพันธ์', 'USR-MIG-0002', '', 'อนุชา สารพันธ์', 'M00065', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [03] ศตเมธ พระแก้ว (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U83ae119ff2499ad8399b1aa743563f84', 'ศตเมธ พระแก้ว', 'USR-MIG-0003', '', 'ศตเมธ พระแก้ว', 'M00051', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [04] วิสันต์ มูลไชย (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U5639b209d2c0145c4190cb4bd0cb5018', 'วิสันต์ มูลไชย', 'USR-MIG-0004', '', 'วิสันต์ มูลไชย', 'D0022', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [05] ภาดล ทองดี (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U00a5a1d33fdc700e7b0c2e33179f05be', 'ภาดล ทองดี', 'USR-MIG-0005', '', 'ภาดล ทองดี', 'M00050', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [06] จันทร์เพ็ญ วงศ์แทน (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U127f79ad9363bb1b015782221498fd4e', 'จันทร์เพ็ญ วงศ์แทน', 'USR-MIG-0006', '', 'phen', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [07] กฤษดา แผ้วฉ่ำ (แผ้ว) (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'Uc424afabc63a230c9007cb2f38058c87', 'กฤษดา แผ้วฉ่ำ (แผ้ว)', 'USR-MIG-0007', '', 'กฤษดา แผ้วฉ่ำ (แผ้ว)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [08] ปิยะพงษ์ คำน้อย (โหน่ง) (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'Ua356ff2bb149bf34cec3f0aadd875f6e', 'ปิยะพงษ์ คำน้อย (โหน่ง)', 'USR-MIG-0008', '', 'ปิยะพงษ์ คำน้อย (โหน่ง)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [09] สมบูรณ์ แซ่ลิ่ม (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U1d9149a04436a3f9194b193d8f0fe138', 'สมบูรณ์ แซ่ลิ่ม', 'USR-MIG-0009', '', 'สมบูรณ์ แซ่ลิ่ม', '', '', 0.00, '', 'Y', '["PC01"]', '["อนุมัติวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [10] สกุณา บ่ายเจริญ (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U6f638fef70908eaf8375ddbe87042b5b', 'สกุณา บ่ายเจริญ', 'USR-MIG-0010', '', 'Nok_Sakuna 🦜', '', '', 0.00, '', 'Y', '["PC01"]', '["อนุมัติวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [11] อาภัสร พักตร์วงศ์สกุล (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U019edef38cb012de8d2d76d4d186b50e', 'อาภัสร พักตร์วงศ์สกุล', 'USR-MIG-0011', '', '', '', '', 0.00, '', 'Y', '["PC01"]', '[]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [12] สุวัฒน์ TEST (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'Ufdb8dd97e54b8652925b36386232c230', 'สุวัฒน์ TEST', 'USR-MIG-0012', '', 'ทดสอบ', 'K000', '', 1.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [13] ลัภนนทน์ ศักดา (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U5b80d103709126e526a98466ed9a056b', 'ลัภนนทน์ ศักดา', 'USR-MIG-0013', '', 'ลัภนนทน์๛(หนึ่ง)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [14] สุเชษฐ์ ดิษคุ้ม (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U2220675d2c220596034e663293e8b5b2', 'สุเชษฐ์ ดิษคุ้ม', 'USR-MIG-0014', '', 'คากิ', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [15] สมชาย ทานุชิต (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'U93bfacf1117eb1f0fe2eab6ed374945c', 'สมชาย ทานุชิต', 'USR-MIG-0015', '', 'Aof', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [16] นันทพงศ์ สุมณีงาม (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'Ubb7fc2ef8df21126e2b1c5dc0795a51f', 'นันทพงศ์ สุมณีงาม', 'USR-MIG-0016', '', 'boatnantapong', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) DO UPDATE SET
    requester_name = excluded.requester_name,
    users_id     = CASE WHEN users_profile.users_id = '' OR users_profile.users_id IS NULL THEN excluded.users_id ELSE users_profile.users_id END,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- Synchronize existing active approvers from legacy approve_users on IMG_DB
UPDATE users_profile
SET approve_tags = json_insert(approve_tags, '$[#]', 'อนุมัติวงเงินสด'),
    updated_at = datetime('now')
WHERE line_uid IN (SELECT line_uid FROM approve_users WHERE active = 1 AND line_uid != '')
  AND approve_tags NOT LIKE '%อนุมัติวงเงินสด%';

-- Record audit trail
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('DATA_MIGRATION', 'ETL_SCRIPT', 'users_profile', '{"migrated_count": 16}');
