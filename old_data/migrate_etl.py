#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
SmartBill ETL Data Migration Script
Purpose: Extract legacy user and approver profiles from Excel (Billing_data.xlsx),
         deduplicate and merge them into the unified SQLite/Cloudflare D1 schema,
         and generate an idempotent SQL script with UPSERT support.
=============================================================================
"""

import os
import sys
import re
import json
import openpyxl

# Ensure UTF-8 output encoding for console
sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXCEL_PATH = os.path.join(SCRIPT_DIR, 'Billing_data.xlsx')
OUTPUT_SQL_PATH = os.path.join(SCRIPT_DIR, 'migrated_users.sql')
OUTPUT_CLOUD_SQL_PATH = os.path.join(SCRIPT_DIR, 'cloud_migrated_users.sql')
OUTPUT_JSON_PATH = os.path.join(SCRIPT_DIR, 'migrated_users.json')

def clean_str(val):
    if val is None:
        return ""
    return str(val).strip()

def normalize_name(name):
    """Normalize Thai name by removing parentheses/nicknames and collapsing whitespaces"""
    if not name:
        return ""
    # remove content inside parentheses e.g. (ฟ้า), (น้ำ), (โหน่ง), (แผ้ว)
    cleaned = re.sub(r'\(.*?\)', '', name)
    cleaned = re.sub(r'（.*?）', '', cleaned)
    # collapse multiple spaces
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned.lower()

def run_etl():
    print("=" * 70)
    print("🚀 Starting SmartBill Legacy Data ETL Process")
    print(f"📁 Source Excel: {EXCEL_PATH}")
    print("=" * 70)

    if not os.path.exists(EXCEL_PATH):
        print(f"❌ Error: Excel file not found at {EXCEL_PATH}")
        sys.exit(1)

    wb = openpyxl.load_workbook(EXCEL_PATH, data_only=True)
    available_sheets = wb.sheetnames
    print(f"📊 Found sheets in workbook: {available_sheets}\n")

    if 'users_profile' not in available_sheets or 'Approve_users' not in available_sheets:
        print("❌ Error: Missing required sheets ('users_profile' or 'Approve_users')")
        sys.exit(1)

    merged_users = {} # Keyed by line_uid (preferred) or normalized name

    # -------------------------------------------------------------------------
    # STEP 1: Process 'users_profile' sheet
    # -------------------------------------------------------------------------
    sheet_users = wb['users_profile']
    print(f"🔹 Processing sheet: 'users_profile' (Rows: {sheet_users.max_row})...")
    users_count = 0

    for r in range(2, sheet_users.max_row + 1):
        raw_uid = clean_str(sheet_users.cell(r, 1).value)
        req_name = clean_str(sheet_users.cell(r, 2).value)
        emp_no = clean_str(sheet_users.cell(r, 3).value)
        raw_limit = sheet_users.cell(r, 4).value
        control = clean_str(sheet_users.cell(r, 5).value).upper()

        if not req_name and not raw_uid:
            continue

        users_count += 1
        try:
            pc_limit = float(raw_limit) if raw_limit is not None else 0.0
        except (ValueError, TypeError):
            pc_limit = 0.0

        is_control = (control == 'YES')

        # Generate primary key key
        key = raw_uid if raw_uid else normalize_name(req_name)

        # Tags
        approve_tags = []
        if is_control:
            approve_tags.append("คุมวงเงินสด")

        merged_users[key] = {
            'users_id': f"USR-MIG-{str(users_count).zfill(4)}",
            'requester_name': req_name,
            'request_name': req_name,
            'Request_Name': req_name,
            'users_name': req_name,
            'line_uid': raw_uid,
            'display_name': '',
            'emp_no': emp_no if emp_no != 'xxxxx' else '',
            'raw_emp_no': emp_no,
            'email': '',
            'pc_limit': pc_limit,
            'avatar_url': '',
            'active': 'Y' if (raw_uid and raw_uid.startswith('U')) else 'N',
            'screen_tags': ['PC01'],
            'approve_tags': approve_tags,
            'source_sheets': ['users_profile']
        }

    print(f"   -> Extracted {users_count} records from 'users_profile'.\n")

    # -------------------------------------------------------------------------
    # STEP 2: Process 'Approve_users' sheet and Merge
    # -------------------------------------------------------------------------
    sheet_app = wb['Approve_users']
    print(f"🔹 Processing sheet: 'Approve_users' (Rows: {sheet_app.max_row})...")
    app_count = 0
    merged_count = 0
    new_from_app_count = 0

    for r in range(2, sheet_app.max_row + 1):
        app_req = clean_str(sheet_app.cell(r, 1).value)
        line_profile = clean_str(sheet_app.cell(r, 2).value)
        raw_uid = clean_str(sheet_app.cell(r, 3).value)
        app_perm = clean_str(sheet_app.cell(r, 4).value).upper()

        if not app_req and not raw_uid:
            continue

        app_count += 1
        is_approver = (app_perm == 'YES')

        # Try to match existing record:
        # Match strategy 1: by line_uid (exact)
        target = None
        if raw_uid and raw_uid in merged_users:
            target = merged_users[raw_uid]
        else:
            # Match strategy 2: by normalized name
            norm = normalize_name(app_req)
            for k, u in merged_users.items():
                if normalize_name(u.get('requester_name', u.get('users_name', ''))) == norm:
                    target = u
                    break

        if target:
            merged_count += 1
            target['source_sheets'].append('Approve_users')
            
            # Enrich display_name from LINE profile
            if line_profile and not target['display_name']:
                target['display_name'] = line_profile

            # Enrich line_uid if missing
            if raw_uid and not target['line_uid']:
                target['line_uid'] = raw_uid
                if raw_uid.startswith('U'):
                    target['active'] = 'Y'

            # User permission rule:
            # pettycash_approve = YES -> สิทธิ์ "อนุมัติวงเงินสด"
            # pettycash_approve = NO  -> สิทธิ์ "คุมวงเงินสด"
            if is_approver:
                if "อนุมัติวงเงินสด" not in target['approve_tags']:
                    target['approve_tags'].append("อนุมัติวงเงินสด")
            else:
                if "คุมวงเงินสด" not in target['approve_tags']:
                    target['approve_tags'].append("คุมวงเงินสด")

        else:
            # Record exists only in Approve_users
            new_from_app_count += 1
            users_count += 1
            key = raw_uid if raw_uid else normalize_name(app_req)

            approve_tags = ["อนุมัติวงเงินสด"] if is_approver else ["คุมวงเงินสด"]

            merged_users[key] = {
                'users_id': f"USR-MIG-{str(users_count).zfill(4)}",
                'requester_name': app_req,
                'request_name': app_req,
                'Request_Name': app_req,
                'users_name': app_req,
                'line_uid': raw_uid,
                'display_name': line_profile,
                'emp_no': '',
                'raw_emp_no': '',
                'email': '',
                'pc_limit': 0.0,
                'avatar_url': '',
                'active': 'Y' if (raw_uid and raw_uid.startswith('U')) else 'N',
                'screen_tags': ['PC01'],
                'approve_tags': approve_tags,
                'source_sheets': ['Approve_users']
            }

    print(f"   -> Extracted {app_count} records from 'Approve_users'.")
    print(f"   -> Successfully merged with existing users: {merged_count} records.")
    print(f"   -> Added new unique records from Approve_users: {new_from_app_count} records.\n")

    # -------------------------------------------------------------------------
    # STEP 3: Generate Idempotent SQL Script (with UPSERT)
    # -------------------------------------------------------------------------
    print("🔹 Generating Idempotent SQL Migration Script (with UPSERT)...")

    sql_statements = [
        "-- =============================================================================",
        "-- SmartBill Migration: Merged Users & Approvers from Legacy Sheets",
        f"-- Generated at: {openpyxl.__name__} ETL Runner",
        f"-- Total Unified Users: {len(merged_users)}",
        "-- Target Table: users_profile (Cloudflare D1 / SQLite)",
        "-- Column Name: requester_name (aligned with Cloud D1 IMG_DB)",
        "-- Strategy: UPSERT via ON CONFLICT(line_uid) DO UPDATE",
        "-- =============================================================================",
        "",
        "PRAGMA foreign_keys = ON;",
        "",
        "BEGIN TRANSACTION;",
        ""
    ]

    export_json_list = []

    cloud_sql_statements = [
        "-- =============================================================================",
        "-- SmartBill Cloud Migration: Merged Users & Approvers for Cloud D1 (IMG_DB)",
        f"-- Generated at: {openpyxl.__name__} ETL Runner",
        f"-- Total Unified Users: {len(merged_users)}",
        "-- Target Table: users_profile in Cloudflare D1 (IMG_DB)",
        "-- Safety Guarantee: Existing car_no, group_car, and timestamps are NOT overwritten!",
        "-- Strategy: UPSERT via ON CONFLICT(line_uid) DO UPDATE",
        "-- =============================================================================",
        "",
        "PRAGMA foreign_keys = ON;",
        ""
    ]

    for idx, user in enumerate(merged_users.values(), 1):
        # Escaping single quotes for SQL
        u_id = user['users_id'].replace("'", "''")
        u_name = user['requester_name'].replace("'", "''")
        raw_uid = user['line_uid'].replace("'", "''")
        # Ensure non-empty line_uid for Primary Key compliance in IMG_DB
        safe_line_uid = raw_uid if raw_uid else f"PENDING:{u_id}"
        u_display = user['display_name'].replace("'", "''")
        u_emp = user['emp_no'].replace("'", "''")
        u_email = user['email'].replace("'", "''")
        u_limit = f"{user['pc_limit']:.2f}"
        u_avatar = user['avatar_url'].replace("'", "''")
        u_active = user['active']
        u_screens = json.dumps(user['screen_tags'], ensure_ascii=False).replace("'", "''")
        u_approves = json.dumps(user['approve_tags'], ensure_ascii=False).replace("'", "''")

        export_json_list.append(user)

        # 1. Local UPSERT Statement
        local_upsert = f"""-- [{idx:02d}] {user['requester_name']} (LINE: {user['display_name'] or 'N/A'})
INSERT INTO users_profile (
    users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    '{u_id}', '', '{u_name}', '{safe_line_uid}', '{u_display}', '{u_emp}', '{u_email}', {u_limit}, '{u_avatar}', '{u_active}', '{u_screens}', '{u_approves}'
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
"""
        sql_statements.append(local_upsert)

        # 2. Cloud (IMG_DB) UPSERT Statement: Preserves car_no & group_car
        cloud_upsert = f"""-- [{idx:02d}] {user['requester_name']} (Safe Cloud Merge)
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (
    '{safe_line_uid}', '{u_name}', '{u_id}', '', '{u_display}', '{u_emp}', '{u_email}', {u_limit}, '{u_avatar}', '{u_active}', '{u_screens}', '{u_approves}'
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
"""
        cloud_sql_statements.append(cloud_upsert)

    # Cloud sync statement: Ensure active approvers from legacy approve_users on IMG_DB receive the tag
    cloud_sql_statements.append("""-- Synchronize existing active approvers from legacy approve_users on IMG_DB
UPDATE users_profile
SET approve_tags = json_insert(approve_tags, '$[#]', 'อนุมัติวงเงินสด'),
    updated_at = datetime('now')
WHERE line_uid IN (SELECT line_uid FROM approve_users WHERE active = 1 AND line_uid != '')
  AND approve_tags NOT LIKE '%อนุมัติวงเงินสด%';
""")

    # Audit log statement
    audit_sql_local = """-- Record audit trail
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('DATA_MIGRATION', 'ETL_SCRIPT', 'users_profile', '{"migrated_count": """ + str(len(merged_users)) + """}');
COMMIT;
"""
    audit_sql_cloud = """-- Record audit trail
INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
VALUES ('DATA_MIGRATION', 'ETL_SCRIPT', 'users_profile', '{"migrated_count": """ + str(len(merged_users)) + """}');
"""
    sql_statements.append(audit_sql_local)
    cloud_sql_statements.append(audit_sql_cloud)

    # Write files
    with open(OUTPUT_SQL_PATH, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql_statements))

    with open(OUTPUT_CLOUD_SQL_PATH, 'w', encoding='utf-8') as f:
        f.write("\n".join(cloud_sql_statements))

    with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(export_json_list, f, ensure_ascii=False, indent=2)

    print(f"✅ Local SQL File written to: {OUTPUT_SQL_PATH}")
    print(f"✅ Cloud SQL File written to: {OUTPUT_CLOUD_SQL_PATH}")
    print(f"✅ JSON File written to: {OUTPUT_JSON_PATH}\n")

    # -------------------------------------------------------------------------
    # STEP 4: Print Summary Table
    # -------------------------------------------------------------------------
    print("=" * 80)
    print(f"{'No.':<4} {'Request Name':<28} {'LINE Profile':<18} {'Limit (฿)':>10} {'Approve Tags':<20}")
    print("=" * 80)
    for i, u in enumerate(export_json_list, 1):
        tags_str = ", ".join(u['approve_tags']) if u['approve_tags'] else '-'
        limit_str = f"{u['pc_limit']:,.0f}"
        disp = u['display_name'] if u['display_name'] else '-'
        print(f"{i:<4} {u['requester_name']:<28} {disp:<18} {limit_str:>10} {tags_str:<20}")
    print("=" * 80)
    print(f"🎉 Migration ETL completed successfully! Total merged users: {len(export_json_list)}\n")

if __name__ == '__main__':
    run_etl()
