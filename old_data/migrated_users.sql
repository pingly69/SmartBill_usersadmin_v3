-- =============================================================================
-- SmartBill Migration: Merged Users & Approvers from Legacy Sheets
-- Generated at: openpyxl ETL Runner
-- Total Unified Users: 16
-- Target Table: users_profile (Cloudflare D1 / SQLite)
-- Column Name: requester_name (aligned with Cloud D1 IMG_DB)
-- Strategy: UPSERT via ON CONFLICT(line_uid) DO UPDATE
-- =============================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- [01] ศิริลักษณ์ ตรียัง(ฟ้า) (LINE: ศิริลักษณ์ ตรียัง)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0001', '', 'ศิริลักษณ์ ตรียัง(ฟ้า)', 'U287b8987ec1a3d3f1c73f56bd88814ea', 'ศิริลักษณ์ ตรียัง', '', '', 30000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [02] อนุชา สารพันธ์ (LINE: อนุชา สารพันธ์)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0002', '', 'อนุชา สารพันธ์', 'Ufb494b7e68ed4b72df584a204146fafd', 'อนุชา สารพันธ์', 'M00065', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [03] ศตเมธ พระแก้ว (LINE: ศตเมธ พระแก้ว)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0003', '', 'ศตเมธ พระแก้ว', 'U83ae119ff2499ad8399b1aa743563f84', 'ศตเมธ พระแก้ว', 'M00051', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [04] วิสันต์ มูลไชย (LINE: วิสันต์ มูลไชย)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0004', '', 'วิสันต์ มูลไชย', 'U5639b209d2c0145c4190cb4bd0cb5018', 'วิสันต์ มูลไชย', 'D0022', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [05] ภาดล ทองดี (LINE: ภาดล ทองดี)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0005', '', 'ภาดล ทองดี', 'U00a5a1d33fdc700e7b0c2e33179f05be', 'ภาดล ทองดี', 'M00050', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [06] จันทร์เพ็ญ วงศ์แทน (LINE: phen)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0006', '', 'จันทร์เพ็ญ วงศ์แทน', 'U127f79ad9363bb1b015782221498fd4e', 'phen', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [07] กฤษดา แผ้วฉ่ำ (แผ้ว) (LINE: กฤษดา แผ้วฉ่ำ (แผ้ว))
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0007', '', 'กฤษดา แผ้วฉ่ำ (แผ้ว)', 'Uc424afabc63a230c9007cb2f38058c87', 'กฤษดา แผ้วฉ่ำ (แผ้ว)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [08] ปิยะพงษ์ คำน้อย (โหน่ง) (LINE: ปิยะพงษ์ คำน้อย (โหน่ง))
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0008', '', 'ปิยะพงษ์ คำน้อย (โหน่ง)', 'Ua356ff2bb149bf34cec3f0aadd875f6e', 'ปิยะพงษ์ คำน้อย (โหน่ง)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [09] สมบูรณ์ แซ่ลิ่ม (LINE: สมบูรณ์ แซ่ลิ่ม)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0009', '', 'สมบูรณ์ แซ่ลิ่ม', 'U1d9149a04436a3f9194b193d8f0fe138', 'สมบูรณ์ แซ่ลิ่ม', '', '', 0.00, '', 'Y', '["PC01"]', '["อนุมัติวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [10] สกุณา บ่ายเจริญ (LINE: Nok_Sakuna 🦜)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0010', '', 'สกุณา บ่ายเจริญ', 'U6f638fef70908eaf8375ddbe87042b5b', 'Nok_Sakuna 🦜', '', '', 0.00, '', 'Y', '["PC01"]', '["อนุมัติวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [11] อาภัสร พักตร์วงศ์สกุล (LINE: N/A)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0011', '', 'อาภัสร พักตร์วงศ์สกุล', 'U019edef38cb012de8d2d76d4d186b50e', '', '', '', 0.00, '', 'Y', '["PC01"]', '[]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [12] สุวัฒน์ TEST (LINE: ทดสอบ)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0012', '', 'สุวัฒน์ TEST', 'Ufdb8dd97e54b8652925b36386232c230', 'ทดสอบ', 'K000', '', 1.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [13] ลัภนนทน์ ศักดา (LINE: ลัภนนทน์๛(หนึ่ง))
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0013', '', 'ลัภนนทน์ ศักดา', 'U5b80d103709126e526a98466ed9a056b', 'ลัภนนทน์๛(หนึ่ง)', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [14] สุเชษฐ์ ดิษคุ้ม (LINE: คากิ)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0014', '', 'สุเชษฐ์ ดิษคุ้ม', 'U2220675d2c220596034e663293e8b5b2', 'คากิ', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [15] สมชาย ทานุชิต (LINE: Aof)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0015', '', 'สมชาย ทานุชิต', 'U93bfacf1117eb1f0fe2eab6ed374945c', 'Aof', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- [16] นันทพงศ์ สุมณีงาม (LINE: boatnantapong)
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    'USR-MIG-0016', '', 'นันทพงศ์ สุมณีงาม', 'Ubb7fc2ef8df21126e2b1c5dc0795a51f', 'boatnantapong', '', '', 5000.00, '', 'Y', '["PC01"]', '["คุมวงเงินสด"]'
)
ON CONFLICT(line_uid) WHERE line_uid IS NOT NULL AND line_uid != '' DO UPDATE SET
    requester_name = excluded.requester_name,
    display_name = CASE WHEN excluded.display_name != '' THEN excluded.display_name ELSE users_profile.display_name END,
    emp_no       = CASE WHEN excluded.emp_no != '' AND excluded.emp_no != 'xxxxx' THEN excluded.emp_no ELSE users_profile.emp_no END,
    pc_limit     = CASE WHEN excluded.pc_limit > 0 THEN excluded.pc_limit ELSE users_profile.pc_limit END,
    active       = excluded.active,
    screen_tags  = excluded.screen_tags,
    approve_tags = excluded.approve_tags,
    updated_at   = datetime('now');

-- Record audit trail
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('DATA_MIGRATION', 'ETL_SCRIPT', 'users_profile', '{"migrated_count": 16}');
COMMIT;
