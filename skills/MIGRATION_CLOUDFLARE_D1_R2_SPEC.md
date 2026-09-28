# Master Technical Specification: Migration from GAS/Google Sheets to Cloudflare Workers + D1 + R2 (TypeScript & SQLite)

**Project:** SmartBill Users Admin (Petty Cash User & Unified Approver Management)  
**Roles:** Chief System Analyst (SA - 30 Yrs Exp) & Principal Database Administrator (DBA)  
**Version:** 3.1.0 (Unified Tag-Based Identity & Approval Architecture with Complete Business Attributes)  
**Target Stack:** Cloudflare Workers (TypeScript) + Cloudflare D1 (SQLite Engine) + Cloudflare R2 (Object Storage)  
**Status:** Approved for Implementation (Ready for Migration Team)

---

## 1. Executive Summary & Architecture Blueprint

### 1.1 ปัญหาของระบบเดิม (Legacy GAS + Google Sheets)
1. **Concurrency & Race Conditions:** การใช้ `LockService.getScriptLock()` บน Google Apps Script มี timeout สูงสุดเพียง 30 วินาที และมีโอกาสเกิด thread starvation เมื่อมี request ชนกันหลายรายการ
2. **High Latency & Cold Starts:** Google Apps Script Web App มี overhead ในการ boot container สูงถึง 1,200ms - 3,500ms ต่อ request ส่งผลต่อ User Experience บน LINE LIFF
3. **Data Fragmentation & Redundancy (ปัญหาการแยก 2 ตารางซ้ำซ้อน):** โครงสร้างเดิมแยก `users_profile` และ `Approve_Users` ออกจากกัน ทั้งที่เป็นข้อมูลของบุคคลคนเดียวกัน ทำให้เกิด overhead ในการทำ synchronization ข้ามตาราง, เสี่ยงต่อข้อมูลหลุดการเชื่อมโยง (Data Inconsistency) เมื่อบันทึกไม่สำเร็จพร้อมกัน และผูกขาดเงื่อนไขการอนุมัติไว้เพียงรูปแบบเดียว (เฉพาะวงเงินสดย่อย) ไม่สามารถขยายสิทธิ์ไปยังหน้าจอ (Screens) หรือสายอนุมัติ (Approval Flows) อื่นๆ ขององค์กรได้อย่างยืดหยุ่น
4. **Data Type Ambiguity:** Google Sheets มีปัญหาเรื่อง auto-formatting เช่น การตัด leading zero ของรหัสพนักงาน หรือสับสนระหว่างตัวเลข 6 หลักกับตัวอักษร

### 1.2 สถาปัตยกรรมระบบใหม่ (Cloudflare Modern Serverless Stack - Unified Architecture)
```
                                 +-------------------------------------------------------+
                                 |            Client Tier (LINE LIFF & Browser)          |
                                 |  index.html + js/app.js (GitHub Pages / CF Pages)     |
                                 +-------------------------------------------------------+
                                                             |
                                                             | HTTPS Fetch (JSON)
                                                             v
+------------------------------------------------------------------------------------------------------------------+
|                                    Cloudflare Edge Network (Sub-50ms Global)                                     |
|                                                                                                                  |
|  +------------------------------------------------------------------------------------------------------------+  |
|  |                             Cloudflare Worker (TypeScript Runtime / Router)                                 |  |
|  |                                                                                                            |  |
|  |  +--------------------+   +-----------------------+   +----------------------+   +-----------------------+  |  |
|  |  | CORS & Rate Limit  |-->| Payload Validation    |-->| Business Logic Core  |-->| Single Table ACID     |  |  |
|  |  | Middleware         |   | & Sanitation (Zod/TS) |   | (Auth & Tag Matrix)  |   | (D1 Operations)       |  |  |
|  |  +--------------------+   +-----------------------+   +----------------------+   +-----------------------+  |  |
|  +------------------------------------------------------------------------------------------------------------+  |
|                                         |                                            |                           |
|                                         v                                            v                           |
|                     +---------------------------------------+    +---------------------------------------+       |
|                     |        Cloudflare D1 (SQLite)         |    |        Cloudflare R2 (Storage)        |       |
|                     |---------------------------------------|    |---------------------------------------|       |
|                     | - users_profile (Unified Table +      |    | - avatars/ (LINE Avatars / Proxy)     |       |
|                     |   pc_limit + Screen & Approver Tags)  |    | - backups/ (Daily D1 JSON dumps)      |       |
|                     | - audit_logs (System audit trail)     |    | - exports/ (CSV/Excel report cache)   |       |
|                     +---------------------------------------+    +---------------------------------------+       |
+------------------------------------------------------------------------------------------------------------------+
```

### 1.3 หลักการสำคัญในการออกแบบ (Design Principles)
* **Single Source of Truth (SSOT) & Complete Schema:** รวม `users_profile` และ `approve_users` ให้เป็นตารางเดียว (`users_profile`) ตามแนวทาง `new_users_profile_and_approve.txt` พร้อมรวบรวมฟิลด์สำคัญที่ระบบเดิมต้องใช้ครบถ้วน ได้แก่ `pc_limit` (วงเงินสดย่อย), `display_name` (ชื่อ LINE Profile เดิม) และ `avatar_url`
* **Tag-Based Authorization (RBAC / ABAC Hybrid):** ใช้ฟิลด์ `screen_tags` ควบคุมสิทธิ์การเข้าถึงหน้าจอ/โมดูล และ `approve_tags` ควบคุมบทบาทการอนุมัติ (เช่น `["คุมวงเงินสด", "อนุมัติวงเงินสด"]`) ในรูปแบบ JSON Array ซึ่งค้นหาและกรองได้รวดเร็วผ่าน SQLite JSON1 extension (`json_each()`) ทำให้ระบบรองรับ webapp อื่นๆ ในอนาคตได้อย่างยืดหยุ่นโดยไม่ต้องแก้โครงสร้างตาราง
* **Zero GAS/Sheet Code:** ตัดคลาสและคำสั่งเฉพาะของ Google ออก 100% (`SpreadsheetApp`, `CacheService`, `PropertiesService`, `LockService`, `ContentService`, `_rowIndex`)
* **Dual-Interface Compatibility:** รักษาความเข้ากันได้กับ Frontend เดิม (`OLD_UI`) แบบ 100% โดย API Gateway จะแปลงข้อมูลระหว่าง Tag-based และ Legacy fields (`pc_limit`, `pettycash_control`, `can_approve`, `Request_Name`, `displayName`) ให้โดยอัตโนมัติ
* **Strict ACID Compliance & High Performance:** ปฏิบัติการบนตารางเดียวทำให้การ Query และ Update มีประสิทธิภาพระดับ Sub-10ms ปราศจากปัญหา Foreign Key Deadlock หรือ Orphan Records

---

## 2. DBA Specification: Cloudflare D1 (SQLite) Schema & Storage Architecture

### 2.1 SQLite Physical Schema Design (DDL)

```sql
-- =============================================================================
-- Migration DDL: SmartBill Users Administration System (Unified Architecture)
-- Target: Cloudflare D1 (SQLite Engine)
-- Reference: skills/new_users_profile_and_approve.txt (Extended with required fields)
-- =============================================================================

-- 1. Enable Foreign Key Constraints
PRAGMA foreign_keys = ON;

-- 2. Drop legacy tables if recreating
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS approve_users; -- Deprecated: Unify completely into users_profile
DROP TABLE IF EXISTS users_profile;

-- -----------------------------------------------------------------------------
-- Table: users_profile
-- Purpose: ตารางเดี่ยวรวมศูนย์ (Unified Table) สำหรับเก็บข้อมูลผู้ใช้งาน, รหัสผ่าน/PIN,
--          การผูก LINE UID, วงเงินสดย่อย, สิทธิ์เข้าถึงหน้าจอ และสิทธิ์การอนุมัติ
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_profile (
  -- Column A: Primary Key (O(1) Generated Unique String เช่น 'USR-0001' หรือ NanoID)
  users_id     TEXT        NOT NULL PRIMARY KEY,
  
  -- Column B: Password (Plain หรือ Hashed สำหรับ Web Login หรือเก็บ PIN 6 หลักชั่วคราวตอนรอ Active)
  password     TEXT        NOT NULL DEFAULT '',
  
  -- Column C: Full Name (Thai/English) - ชื่อ-นามสกุลของผู้ใช้งาน (เทียบเท่า Request_Name เดิม)
  users_name   TEXT        NOT NULL DEFAULT '',
  
  -- Column D: LINE UID (Optional จาก LINE LIFF เช่น 'U1234567890abcdef...')
  --           เมื่อผู้ใช้ยังไม่ผูก LINE จะเป็นค่าว่าง '' หรือ NULL
  line_uid     TEXT        NULL DEFAULT '',

  -- Column E: LINE Display Name (ชื่อโปรไฟล์ LINE ที่ผูกแล้ว เทียบเท่า line_profile เดิม)
  display_name TEXT        NULL DEFAULT '',
  
  -- Column F: Employee Number (รหัสพนักงาน เก็บเป็น TEXT เพื่อรักษา Leading Zeros เช่น '00412')
  emp_no       TEXT        NULL DEFAULT '',
  
  -- Column G: Email (อีเมลสำหรับติดต่อหรือรับการแจ้งเตือน)
  email        TEXT        NULL DEFAULT '',
  
  -- Column H: Petty Cash Limit (วงเงินสดย่อย บาท บังคับ >= 0 จาก users_profile เดิม)
  pc_limit     REAL        NOT NULL DEFAULT 0.00 CHECK (pc_limit >= 0),
  
  -- Column I: Avatar URL (URL รูปโปรไฟล์ LINE หรือ URL แคชบน R2)
  avatar_url   TEXT        NULL DEFAULT '',

  -- Column J: Account Status ('Y' = Active, 'N' = Inactive / รอ Admin อนุมัติ หรือ รอผูก PIN)
  --           ค่า Default เมื่อสร้างใหม่ = 'N'
  active       TEXT        NOT NULL DEFAULT 'N' CHECK (active IN ('Y', 'N')),
  
  -- Column K: Screen Authorization Tags (JSON Array stored as TEXT)
  --           ระบุรหัสหน้าจอที่ผู้ใช้มีสิทธิ์เข้าถึง ตัวอย่าง: '["PC01","PC02"]'
  screen_tags  TEXT        NOT NULL DEFAULT '[]',
  
  -- Column L: Approver Tags (JSON Array stored as TEXT)
  --           ระบุบทบาทการอนุมัติของผู้ใช้ ตัวอย่าง: '["คุมวงเงินสด","อนุมัติวงเงินสด"]'
  approve_tags TEXT        NOT NULL DEFAULT '[]',
  
  -- Audit fields
  created_at   TEXT        NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT        NOT NULL DEFAULT (datetime('now'))
);

-- Index สำหรับค้นหาด้วย line_uid (O(1) Lookup แบบ Partial Unique Index)
-- อนุญาตให้แถวที่เป็นค่าว่างมีหลายแถวได้ แต่แถวที่มีค่า LINE UID จริงจะต้อง Unique เสมอ
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_profile_line_uid
  ON users_profile (line_uid)
  WHERE line_uid IS NOT NULL AND line_uid != '';

-- Index สำหรับ Query ผู้ใช้ Active / Inactive
CREATE INDEX IF NOT EXISTS idx_users_profile_active
  ON users_profile (active);

-- Index สำหรับค้นหาด้วยชื่อผู้ใช้ (Case-Insensitive)
CREATE INDEX IF NOT EXISTS idx_users_profile_users_name
  ON users_profile (users_name COLLATE NOCASE);

-- Index สำหรับค้นหาด้วยรหัสพนักงาน
CREATE INDEX IF NOT EXISTS idx_users_profile_emp_no
  ON users_profile (emp_no);

-- -----------------------------------------------------------------------------
-- Table: audit_logs
-- Purpose: บันทึกประวัติการกระทำของ Admin และกระบวนการ Register (Audit Trail)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    action            TEXT NOT NULL,       -- 'CREATE_USER', 'UPDATE_USER', 'DELETE_USER', 'REGISTER_USER', 'VERIFY_PIN'
    performed_by      TEXT NOT NULL,       -- 'ADMIN' หรือ LINE UID / IP
    target_identifier TEXT,                -- users_id, users_name หรือ line_uid
    details_json      TEXT,                -- JSON snapshot ก่อน/หลัง
    ip_address        TEXT,
    user_agent        TEXT,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs (target_identifier);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);
```

### 2.2 Data Migration Mapping & Data Dictionary (จาก Google Sheets สู่ D1 Unified Table)

| Google Sheet Source | Legacy Type | D1 Unified Column | D1 Type & Constraints | Data Transformation / Handling Rule |
|---|---|---|---|---|
| *(Auto Gen / Row)* | - | `users_id` | `TEXT NOT NULL PRIMARY KEY` | สร้าง Identifier ประจำผู้ใช้ เช่น `USR-0001` หรือสร้างจาก hash/nanoid ป้องกัน ID ซ้ำ |
| `users_profile.line_uid` | string | `line_uid` / `password` | `TEXT NULL DEFAULT ''` | • หากเป็น LINE UID จริง (`^U[0-9a-fA-F]{32}$`) -> ใส่ลงใน `line_uid` และกำหนด `active = 'Y'`<br>• หากเป็น PIN ตัวเลข 6 หลัก -> นำไปเก็บใน `password` กำหนด `active = 'N'` และให้ `line_uid = ''` |
| `users_profile.Request_Name`<br>หรือ `Approve_Users.approve_request` | string | `users_name` | `TEXT NOT NULL DEFAULT ''` | ผสานชื่อผู้ใช้เป็นบุคคลเดียวกัน Trim whitespace, Normalize multi-spaces เป็น single space |
| `Approve_Users.line_profile` | string | `display_name` | `TEXT NULL DEFAULT ''` | เก็บชื่อโปรไฟล์ LINE (เมื่อผู้ใช้ยังไม่ผูก LINE จะเป็นค่าว่าง) |
| `users_profile.emp_no` | string | `emp_no` | `TEXT NULL DEFAULT ''` | Trim whitespace, เก็บเป็น TEXT เสมอ ห้ามแปลงเป็น number เพื่อรักษา Leading Zeros |
| `users_profile.pc.limit` | number | `pc_limit` | `REAL NOT NULL DEFAULT 0.00` | Parse float, fallback เป็น `0.00` หากว่างหรือ null |
| *(New / Extensible)* | - | `email` | `TEXT NULL DEFAULT ''` | เก็บอีเมลผู้ใช้งาน (หากไม่มีให้เป็นค่าว่าง) |
| *(New / R2 Link)* | - | `avatar_url` | `TEXT NULL DEFAULT ''` | URL รูปโปรไฟล์ LINE หรือ URL แคชบน Cloudflare R2 |
| *(Calculated Status)* | - | `active` | `TEXT NOT NULL CHECK (active IN ('Y', 'N'))` | • `'Y'` เมื่อผูก LINE UID แล้ว หรือได้รับการอนุมัติใช้งาน<br>• `'N'` เมื่อสร้างใหม่ (Pending) รอส่ง PIN ให้ผู้ใช้ลงทะเบียน |
| `users_profile.pettycash_control` | string | `approve_tags` (ส่วนหนึ่ง) | `TEXT NOT NULL DEFAULT '[]'` | แปลงค่า: หาก `pettycash_control == 'YES'` ให้เพิ่มแท็ก `"คุมวงเงินสด"` ลงใน JSON Array |
| `Approve_Users.pettycash_approve` | string | `approve_tags` (ส่วนหนึ่ง) | `TEXT NOT NULL DEFAULT '[]'` | แปลงค่า: หาก `pettycash_approve == 'YES'` ให้เพิ่มแท็ก `"อนุมัติวงเงินสด"` ลงใน JSON Array |
| *(Screen Authorization)* | - | `screen_tags` | `TEXT NOT NULL DEFAULT '[]'` | กำหนดสิทธิ์หน้าจอเริ่มต้น เช่น `["PC01"]` (วงเงินสดย่อย) หรือ `["ADMIN"]` ตามบทบาท |

### 2.3 การ Query ข้อมูลด้วย Tag-Based Authorization (SQLite JSON1)

ระบบใหม่ใช้ความสามารถของ SQLite JSON1 Extension (`json_each`) เพื่อค้นหากรองผู้ใช้และผู้อนุมัติตามที่ระบุใน `new_users_profile_and_approve.txt`:

```sql
-- 1. ค้นหาผู้อนุมัติที่เป็น "ผู้ถือ/คุมวงเงินสด" ที่เปิดใช้งานอยู่ (active = 'Y')
SELECT u.users_id, u.users_name, u.emp_no, u.pc_limit, u.line_uid, u.approve_tags
FROM users_profile u, json_each(u.approve_tags) j
WHERE u.active = 'Y' 
  AND j.value = 'คุมวงเงินสด';

-- 2. ค้นหาผู้อนุมัติสำหรับการ "อนุมัติการจ่ายชดเชยวงเงินสด"
SELECT u.users_id, u.users_name, u.emp_no, u.line_uid, u.approve_tags
FROM users_profile u, json_each(u.approve_tags) j
WHERE u.active = 'Y' 
  AND j.value = 'อนุมัติวงเงินสด';

-- 3. ตรวจสอบว่าผู้ใช้งานมีสิทธิ์เข้าถึงหน้าจอ 'PC01' หรือไม่
SELECT EXISTS(
  SELECT 1 
  FROM json_each(screen_tags) 
  WHERE value = 'PC01'
) AS has_permission
FROM users_profile 
WHERE users_id = ? AND active = 'Y';
```

### 2.4 Automated Updated_At Triggers (SQLite)
```sql
CREATE TRIGGER IF NOT EXISTS trg_users_profile_updated_at
AFTER UPDATE ON users_profile
FOR EACH ROW
BEGIN
    UPDATE users_profile SET updated_at = datetime('now') WHERE users_id = OLD.users_id;
END;
```

---

## 3. Object Storage Specification: Cloudflare R2

### 3.1 วัตถุประสงค์และโครงสร้าง R2 Bucket
กำหนดชื่อ Bucket ใน Cloudflare: `smartbill-assets` (หรือกำหนดผ่าน `env.ASSETS_BUCKET`)

```
smartbill-assets/
├── avatars/
│   ├── {line_uid}.webp           # รูปโปรไฟล์ LINE ที่ถูกแคชมาเก็บใน R2 (ลดการโหลดซ้ำจาก LINE CDN)
│   └── default-avatar.svg        # รูป Fallback ประจำระบบ
├── backups/
│   └── d1_dump_{YYYYMMDD_HHmmss}.json.gz  # Snapshot สำรองข้อมูล D1 ประจำวัน
└── exports/
    └── users_export_{timestamp}.csv       # แคชรายงานที่ Admin export
```

### 3.2 R2 Lifecycle & Storage Class
* **Avatars (`avatars/`):** Standard storage, Public read access ผ่าน Cloudflare Worker Custom Domain หรือ Pre-signed URL
* **Backups (`backups/`):** เก็บ 30 วัน แล้ว purge อัตโนมัติ (ตั้งค่าผ่าน R2 Lifecycle Rules: Expiration = 30 days)
* **Exports (`exports/`):** เก็บ 24 ชั่วโมง แล้ว purge อัตโนมัติ (Expiration = 1 day)

---

## 4. System Analyst (SA) Specification: Business Logic Engine

### 4.1 State Machine ของ Unified User Profile

```
               [ Admin Creates User ]
                         |
                         v
       +------------------------------------+
       |          STATUS = PENDING          |
       | - active = 'N'                     |
       | - password = 6-digit numeric PIN   |
       | - pc_limit = Assigned Limit (฿)    |
       | - line_uid = '' (or NULL)          |
       | - screen_tags = '["PC01"]'         |
       | - approve_tags = [...]             |
       +------------------------------------+
                         |
           User inputs PIN via LINE LIFF
                         |
                         v
             [ Verification Check ]
                         |
             +-----------+-----------+
             |                       |
     (PIN Invalid)            (PIN Matched)
             |                       |
             v                       v
    [ Reject (401) ]       [ LIFF getProfile() ]
    "รหัสไม่ถูกต้อง"        [ Retrieve userId, displayName, pictureUrl ]
                                     |
                                     v
                       +----------------------------+
                       |    STATUS = REGISTERED     |
                       | - active = 'Y'             |
                       | - line_uid = LINE UID (U...)|
                       | - display_name = Line Name |
                       | - avatar_url = Picture URL |
                       | - Single Table Update      |
                       +----------------------------+
```

* **นิยามสถานะ "PENDING" (รอลงทะเบียน / รอเปิดใช้งาน):**
  * `active = 'N'`
  * `password` เก็บตัวเลข PIN 6 หลักสำหรับให้พนักงานนำไปกรอกยืนยันตน
  * `line_uid` เป็นค่าว่าง (`''` หรือ `NULL`)
* **นิยามสถานะ "REGISTERED" (ลงทะเบียนผูก LINE แล้ว):**
  * `active = 'Y'`
  * `line_uid` เป็น LINE UID จริง (เช่น `^U[0-9a-fA-F]{32}$`)
  * `display_name` ได้รับการอัปเดตจาก LINE Display Name

---

### 4.2 กฎการตรวจสอบสิทธิ์และการเข้าใช้งาน (Authentication Rule)

เมื่อมีการเรียกใช้งาน Action: `verifyPin` พร้อมรหัส 6 หลัก:
1. **Priority 1: ตรวจสอบเทียบกับ Admin PIN (`env.ADMIN_PINCODE`) ก่อนเสมอ**
   * หาก `inputPin === env.ADMIN_PINCODE`:
     * ตอบรับทันที: `{ success: true, role: 'ADMIN', message: 'เข้าสู่ระบบผู้ดูแลระบบสำเร็จ', usersList: [...] }`
     * ไม่ต้องค้นหาในตาราง User ใดๆ
2. **Priority 2: ค้นหาใน `users_profile` ที่มีสถานะ PENDING**
   * ตรวจสอบเทียบกับ `password` (หรือ `line_uid` ชั่วคราว) ที่ `active = 'N'`:
     ```sql
     SELECT users_id, users_name, emp_no, email, pc_limit, active, screen_tags, approve_tags 
     FROM users_profile 
     WHERE (password = ? OR line_uid = ?) AND active = 'N';
     ```
   * หากพบ record:
     * ดึงข้อมูลผู้ใช้ พร้อมแปลง tags คืนกลับให้ Client
     * ตอบรับ: 
       ```json
       {
         "success": true,
         "role": "USER",
         "isPending": true,
         "data": {
           "usersId": "USR-001",
           "requestName": "สมชาย ใจดี",
           "usersName": "สมชาย ใจดี",
           "empNo": "00521",
           "pcLimit": 5000,
           "email": "somchai@company.com",
           "screenTags": ["PC01"],
           "approveTags": ["คุมวงเงินสด"],
           "pettycashControl": "YES"
         },
         "message": "พบข้อมูลผู้ใช้ พร้อมทำการลงทะเบียน"
       }
       ```
3. **Priority 3: ปฏิเสธการเข้าถึง (Rejection)**
   * หากไม่ตรงกับข้อ 1 และ 2:
     * ตอบกลับ: `{ success: false, message: 'รหัสไม่ถูกต้อง' }` (ป้องกันการ Brute-force / PIN Enumeration)

---

### 4.3 กฎการสร้าง PIN สุ่ม 6 หลัก (Cryptographic Secure PIN Generation)

* **ช่วงตัวเลข:** `[100000, 999999]` (ความยาว 6 หลัก ไม่ขึ้นต้นด้วย 0)
* **Entropy Source:** ใช้ Web Crypto API `crypto.getRandomValues(new Uint32Array(1))` ห้ามใช้ `Math.random()`
* **Collision Check (Single Table Verification):**
  * ตรวจสอบไม่ให้ตรงกับ `env.ADMIN_PINCODE`
  * ตรวจสอบไม่ให้ตรงกับ `password` ของผู้ใช้คนอื่นที่ยังค้างอยู่ในสถานะ Pending (`active = 'N' AND length(password) = 6`)
  * ปฏิบัติการตรวจสอบในตารางเดียว `users_profile` รวดเร็วและแม่นยำสูง
* **Retry Safety Cap:** สุ่มซ้ำสูงสุด 50 รอบ หากยังชนให้ Throw Error ป้องกัน infinite loop

---

### 4.4 สถาปัตยกรรมสิทธิ์แบบ Tag-Based (Tag-Based Role & Permission Architecture)

#### 4.4.1 เหตุผลความจำเป็นในการยกเลิกตารางแยก (`approve_users`)
ในระบบเดิม การแยกตาราง `approve_users` ออกจาก `users_profile` ก่อให้เกิดข้อจำกัดรุนแรง 3 ประการ:
1. **Redundant Synchronization:** ทุกครั้งที่มีการเพิ่ม/ลบ/แก้ไข หรือลงทะเบียน ต้องใช้ transaction วิ่งแก้ 2 ตารางพร้อมกัน เสี่ยงต่อการเกิด data inconsistent
2. **Hardcoded Workflow:** ตารางเดิมผูกมัดเฉพาะสิทธิ์การอนุมัติเงินชดเชยของ Petty Cash เท่านั้น (`pettycash_approve = 'YES'/'NO'`) ทำให้ไม่สามารถนำระบบบริหารจัดการผู้ใช้นี้ไปใช้กับ Application อื่นได้
3. **Rigid Mutual Exclusion Rule:** กฎเดิมบังคับว่าคนคุมเงินสดต้องมี record แต่ถูกบังคับ `pettycash_approve = 'NO'` ซึ่งเป็น logic ที่ผูกติดกับ business ยุคเก่ามากเกินไป

#### 4.4.2 การออกแบบใหม่ด้วย Tag Matrix (`screen_tags` & `approve_tags`)
ระบบใหม่ผสานข้อมูลทั้งหมดไว้ในตารางเดียว (`users_profile`) โดยใช้ Tag Arrays ในรูปแบบ JSON:

1. **`screen_tags` (สิทธิ์ระดับหน้าจอ / UI Screen Authorization):**
   * ควบคุมว่าผู้ใช้คนนี้สามารถมองเห็นหรือเข้าใช้งานหน้าจอใดได้บ้าง เช่น:
     * `"PC01"` = หน้าจอยื่นคำขอเบิกเงินสดย่อย
     * `"PC02"` = หน้าจอบันทึกการจ่ายชดเชยเงินสดย่อย
     * `"ADMIN"` = หน้าจอจัดการผู้ใช้และสิทธิ์
   * รองรับการเพิ่มรหัสหน้าจอใหม่ของแต่ละ webapp ได้ไม่จำกัด

2. **`approve_tags` (บทบาทและสิทธิ์การอนุมัติ / Workflow Capability Tags):**
   * ควบคุมว่าผู้ใช้คนนี้มีอำนาจหน้าที่อนุมัติในเรื่องใดบ้าง เช่น:
     * `"คุมวงเงินสด"` = ผู้ถือวงเงินสดย่อย (Petty Cash Custodian)
     * `"อนุมัติวงเงินสด"` = ผู้มีอำนาจอนุมัติเงินสดย่อย / อนุมัติชดเชยเงินเข้าวงเงิน
     * `"อนุมัติจัดซื้อ"` = ผู้อนุมัติใบขอซื้อ (PO Approver)
     * `"ผู้ตรวจสอบ"` = Internal Auditor

#### 4.4.3 วิธีใช้งานสำหรับ Web Applications ต่างๆ (Dynamic Filter Engine)
เมื่อแต่ละ Web Application หรือแต่ละหน้าจอต้องการรายชื่อผู้อนุมัติ:
* **หน้าจอต้องการรายชื่อผู้ถือ/คุมวงเงินสด:**
  * ฝั่ง Client ส่ง Request: `{ action: "getApprovers", tag: "คุมวงเงินสด" }`
  * ฝั่ง Worker ค้นหาผู้ใช้ที่มี `active = 'Y'` และ `approve_tags` มีคำว่า `"คุมวงเงินสด"`
* **หน้าจอต้องการรายชื่อผู้อนุมัติการจ่ายชดเชยเงินสด:**
  * ฝั่ง Client ส่ง Request: `{ action: "getApprovers", tag: "อนุมัติวงเงินสด" }`
  * ฝั่ง Worker ค้นหาผู้ใช้ที่มี `active = 'Y'` และ `approve_tags` มีคำว่า `"อนุมัติวงเงินสด"`
* **หน้าจอของระบบอื่นในอนาคต (เช่น จัดซื้อ):**
  * ค้นหา `{ action: "getApprovers", tag: "อนุมัติจัดซื้อ" }` ได้ทันทีโดย **ไม่ต้องสร้างตารางใหม่ และไม่ต้องเพิ่มคอลัมน์ในฐานข้อมูล**

#### 4.4.4 Compatibility Mapping Matrix (สะพานเชื่อมระหว่างระบบเดิมกับระบบใหม่)

| Legacy Field | Modern Schema (`users_profile`) | Inbound Transformation (เมื่อบันทึกจาก UI เก่า) | Outbound Transformation (เมื่อส่งข้อมูลกลับไป UI เก่า) |
|---|---|---|---|
| `Request_Name` | `users_name` | บันทึกลง `users_name` | ส่งออกเป็น `Request_Name` และ `users_name` |
| `emp_no` | `emp_no` | บันทึกลง `emp_no` | ส่งออกเป็น `emp_no` และ `empNo` |
| `pc_limit` / `pcLimit` | `pc_limit` | บันทึกลง `pc_limit` (REAL) | ส่งออกเป็น `pc_limit` และ `pcLimit` (Number) |
| `line_profile` / `displayName` | `display_name` | บันทึกลง `display_name` | ส่งออกเป็น `displayName` และ `display_name` |
| `pettycash_control` | `approve_tags` | หากค่าคือ `'YES'` ให้เพิ่มแท็ก `"คุมวงเงินสด"` ลงใน Array | หาก Array มี `"คุมวงเงินสด"` -> ส่งออก `'YES'` มิฉะนั้น `'NO'` |
| `can_approve` / `pettycash_approve` | `approve_tags` | หากค่าคือ `true` หรือ `'YES'` ให้เพิ่มแท็ก `"อนุมัติวงเงินสด"` | หาก Array มี `"อนุมัติวงเงินสด"` -> ส่งออก `'YES'` / `true` |
| `status` | `active` & `line_uid` | - | `active === 'Y' && line_uid != '' ? 'REGISTERED' : 'PENDING'` |

---

### 4.5 กฎการจัดการ Transaction ในแต่ละ Use Case (Single Table ACID)

#### Use Case 1: Create User (เพิ่มผู้ใช้ใหม่)
1. Validate `users_name` (หรือ `Request_Name`) ไม่เป็นค่าว่าง
2. ตรวจสอบ Uniqueness ของ `users_name` (Case-Insensitive) จากตาราง `users_profile`
3. สร้าง Unique `users_id` (เช่น `'USR-' + nanoid()`)
4. สุ่ม Unique PIN 6 หลัก
5. ประกอบ Tags & Attributes:
   * ดึงค่า `pc_limit` (ค่าเริ่มต้น 0.00)
   * แปลงค่า legacy `pettycash_control` และ `can_approve` เข้าสู่ `approve_tags` (หรือรับ `approve_tags` โดยตรง)
   * กำหนด `screen_tags` เริ่มต้น (default: `["PC01"]`)
6. บันทึกคำสั่ง SQL ลงใน `d1.batch`:
   * Statement 1:
     ```sql
     INSERT INTO users_profile (
       users_id, password, users_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
     ) VALUES (?1, ?2, ?3, '', '', ?4, ?5, ?6, '', 'N', ?7, ?8);
     ```
   * Statement 2 (Audit Log):
     ```sql
     INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
     VALUES ('CREATE_USER', 'ADMIN', ?1, ?2);
     ```
7. Return `{ success: true, message: 'เพิ่มผู้ใช้ใหม่สำเร็จ', data: { pin, users_id, users_name, pc_limit, ... } }`

#### Use Case 2: Update User (แก้ไขผู้ใช้)
1. ค้นหาแถวผู้ใช้ด้วย `users_id` หรือ `line_uid` เดิม
2. หากมีการเปลี่ยนชื่อ ตรวจสอบไม่ให้ซ้ำกับผู้ใช้อื่น
3. ตรวจสอบการขอสร้าง PIN ใหม่ (`regenerate_pin = true`):
   * ทำได้เฉพาะเมื่อผู้ใช้ยังมีสถานะ Pending (`active = 'N'`)
   * สุ่ม PIN ใหม่ และอัปเดตลงฟิลด์ `password`
4. อัปเดต `users_profile` ในคำสั่งเดียว:
   ```sql
   UPDATE users_profile
   SET users_name = ?1,
       emp_no = ?2,
       email = ?3,
       pc_limit = ?4,
       password = CASE WHEN ?5 != '' THEN ?5 ELSE password END,
       screen_tags = ?6,
       approve_tags = ?7,
       updated_at = datetime('now')
   WHERE users_id = ?8;
   ```
5. บันทึก Audit Log และ Return ผลลัพธ์

#### Use Case 3: Register User (LINE LIFF Identity Binding)
1. Input: `pin` (6 หลัก), `lineUid` (LINE User ID จริง), `displayName` (ชื่อ LINE), `pictureUrl` (รูปโปรไฟล์)
2. ค้นหาผู้ใช้จากตาราง `users_profile` ที่ `password = pin AND active = 'N'`
3. หากไม่พบ -> Return error: `'ไม่พบรายการผู้ใช้ที่รอลงทะเบียนด้วยรหัส PIN นี้ (อาจมีการลงทะเบียนไปแล้ว)'`
4. อัปเดตสถานะและผูก LINE UID ลงในคำสั่งเดียว:
   * Statement 1:
     ```sql
     UPDATE users_profile 
     SET line_uid = ?1,
         display_name = ?2,
         avatar_url = ?3,
         active = 'Y', 
         updated_at = datetime('now') 
     WHERE users_id = ?4;
     ```
   * Statement 2 (Audit Log):
     ```sql
     INSERT INTO audit_logs (action, performed_by, target_identifier, details_json) 
     VALUES ('REGISTER_USER', ?1, ?2, ?5);
     ```
5. Return `{ success: true, message: 'ยืนยันตัวตนสำเร็จ', data: { lineUid, displayName, usersName } }`

#### Use Case 4: Delete User (ลบผู้ใช้)
1. ค้นหาผู้ใช้เพื่อดึง identifier
2. ลบผู้ใช้ออกจากตาราง `users_profile` โดยตรง:
   * Statement 1: `DELETE FROM users_profile WHERE users_id = ?1 OR line_uid = ?1;`
   * Statement 2: `INSERT INTO audit_logs (action, performed_by, target_identifier) VALUES ('DELETE_USER', 'ADMIN', ?1);`
3. Return `{ success: true, message: 'ลบผู้ใช้เรียบร้อยแล้ว' }`

#### Use Case 5: Get Approvers by Tag (ดึงรายชื่อผู้อนุมัติตามแท็ก)
1. Input: `tag` (เช่น `"คุมวงเงินสด"`, `"อนุมัติวงเงินสด"`)
2. ค้นหาผู้ใช้ที่มีสถานะ Active และมีแท็กดังกล่าว:
   ```sql
   SELECT u.users_id, u.users_name, u.emp_no, u.pc_limit, u.line_uid, u.display_name, u.email, u.screen_tags, u.approve_tags
   FROM users_profile u, json_each(u.approve_tags) j
   WHERE u.active = 'Y' AND j.value = ?;
   ```
3. Return `{ success: true, tag: tag, data: [...] }`

---

## 5. API Specification & Interface Contracts

เพื่อให้ระบบ Frontend เดิม (`js/app.js`) ใช้งานได้ทันที 100% โดยไม่ต้องแก้ฟังก์ชัน `callApi` ภายใน Web App:
* Endpoint URL: `https://<your-worker-domain>/api`
* Method: `POST` (และรองรับ `GET /api?action=...`)
* Content-Type: `text/plain;charset=utf-8` หรือ `application/json` (รองรับทั้งคู่)

### 5.1 Request / Response Schemas

#### 1. Action: `verifyPin`
* **Request:**
  ```json
  {
    "action": "verifyPin",
    "pin": "123456"
  }
  ```
* **Success Response (Admin):**
  ```json
  {
    "success": true,
    "role": "ADMIN",
    "message": "เข้าสู่ระบบผู้ดูแลระบบสำเร็จ",
    "usersList": [ /* รายการ users ทั้งหมด */ ]
  }
  ```
* **Success Response (Pending User):**
  ```json
  {
    "success": true,
    "role": "USER",
    "isPending": true,
    "data": {
      "usersId": "USR-001",
      "requestName": "สมชาย ใจดี",
      "usersName": "สมชาย ใจดี",
      "empNo": "00521",
      "pcLimit": 5000,
      "email": "somchai@company.com",
      "screenTags": ["PC01"],
      "approveTags": ["คุมวงเงินสด"],
      "pettycashControl": "YES"
    },
    "message": "พบข้อมูลผู้ใช้ พร้อมทำการลงทะเบียน"
  }
  ```
* **Error Response:**
  ```json
  {
    "success": false,
    "message": "รหัสไม่ถูกต้อง"
  }
  ```

#### 2. Action: `registerUser`
* **Request:**
  ```json
  {
    "action": "registerUser",
    "pin": "123456",
    "lineUid": "U1234567890abcdef1234567890abcdef",
    "displayName": "Somchai.J",
    "pictureUrl": "https://profile.line-scdn.net/..."
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "message": "ยืนยันตัวตนสำเร็จ",
    "data": {
      "lineUid": "U1234567890abcdef1234567890abcdef",
      "displayName": "Somchai.J",
      "usersName": "สมชาย ใจดี",
      "requestName": "สมชาย ใจดี"
    }
  }
  ```

#### 3. Action: `listUsers`
* **Request:**
  ```json
  {
    "action": "listUsers",
    "adminPin": "999999"
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "users_id": "USR-001",
        "users_name": "สมชาย ใจดี",
        "Request_Name": "สมชาย ใจดี",
        "emp_no": "00521",
        "email": "somchai@company.com",
        "pc_limit": 5000,
        "line_uid": "U1234567890abcdef1234567890abcdef",
        "display_name": "Somchai.J",
        "displayName": "Somchai.J",
        "avatar_url": "https://smartbill-assets.workers.dev/avatars/U1234.webp",
        "active": "Y",
        "status": "REGISTERED",
        "isPending": false,
        "screen_tags": ["PC01"],
        "approve_tags": ["อนุมัติวงเงินสด"],
        "pettycash_control": "NO",
        "pettycash_approve": "YES",
        "can_approve": true
      },
      {
        "users_id": "USR-002",
        "users_name": "สมหญิง รักงาน",
        "Request_Name": "สมหญิง รักงาน",
        "emp_no": "00522",
        "email": "somying@company.com",
        "pc_limit": 10000,
        "line_uid": "481920",
        "display_name": "",
        "displayName": "",
        "avatar_url": "",
        "active": "N",
        "status": "PENDING",
        "isPending": true,
        "screen_tags": ["PC01", "PC02"],
        "approve_tags": ["คุมวงเงินสด"],
        "pettycash_control": "YES",
        "pettycash_approve": "NO",
        "can_approve": false
      }
    ]
  }
  ```

#### 4. Action: `createUser`
* **Request (รองรับทั้งฟิลด์ใหม่และฟิลด์เดิม):**
  ```json
  {
    "action": "createUser",
    "users_name": "วิชัย เจริญพร",
    "Request_Name": "วิชัย เจริญพร",
    "emp_no": "00523",
    "email": "wichai@company.com",
    "pc_limit": 20000,
    "screen_tags": ["PC01"],
    "approve_tags": ["อนุมัติวงเงินสด"],
    "pettycash_control": "NO",
    "can_approve": true
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "message": "เพิ่มผู้ใช้ใหม่สำเร็จ",
    "data": {
      "pin": "719302",
      "users_id": "USR-003",
      "users_name": "วิชัย เจริญพร",
      "Request_Name": "วิชัย เจริญพร",
      "emp_no": "00523",
      "email": "wichai@company.com",
      "pc_limit": 20000,
      "screen_tags": ["PC01"],
      "approve_tags": ["อนุมัติวงเงินสด"],
      "pettycash_control": "NO",
      "can_approve": true
    }
  }
  ```

#### 5. Action: `updateUser`
* **Request:**
  ```json
  {
    "action": "updateUser",
    "users_id": "USR-003",
    "target_line_uid": "719302",
    "users_name": "วิชัย เจริญพร (แก้ไข)",
    "Request_Name": "วิชัย เจริญพร (แก้ไข)",
    "emp_no": "00523",
    "email": "wichai_new@company.com",
    "pc_limit": 25000,
    "screen_tags": ["PC01", "PC02"],
    "approve_tags": ["คุมวงเงินสด"],
    "pettycash_control": "YES",
    "can_approve": false,
    "regenerate_pin": false
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "message": "บันทึกการแก้ไขข้อมูลสำเร็จ",
    "data": null
  }
  ```

#### 6. Action: `deleteUser`
* **Request:**
  ```json
  {
    "action": "deleteUser",
    "users_id": "USR-003",
    "line_uid": "719302",
    "adminPin": "999999"
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "message": "ลบผู้ใช้เรียบร้อยแล้ว"
  }
  ```

#### 7. Action: `getApprovers` (ดึงรายชื่อผู้อนุมัติตาม Tag)
* **Request:**
  ```json
  {
    "action": "getApprovers",
    "tag": "คุมวงเงินสด"
  }
  ```
* **Response:**
  ```json
  {
    "success": true,
    "tag": "คุมวงเงินสด",
    "data": [
      {
        "users_id": "USR-002",
        "users_name": "สมหญิง รักงาน",
        "emp_no": "00522",
        "pc_limit": 10000,
        "line_uid": "U9876543210...",
        "display_name": "Somying.R",
        "email": "somying@company.com",
        "approve_tags": ["คุมวงเงินสด"]
      }
    ]
  }
  ```

---

## 6. Implementation Code Blueprint (TypeScript)

### 6.1 Project Configuration (`wrangler.toml`)
```toml
name = "smartbill-usersadmin-api"
main = "src/index.ts"
compatibility_date = "2024-09-01"
compatibility_flags = [ "nodejs_compat" ]

# D1 Database Binding
[[d1_databases]]
binding = "DB"
database_name = "smartbill-prod-db"
database_id = "<YOUR_D1_DATABASE_ID>"

# R2 Object Storage Binding
[[r2_buckets]]
binding = "STORAGE"
bucket_name = "smartbill-assets"

# Environment Variables
[vars]
CORS_ALLOW_ORIGIN = "*"
PIN_MIN = 100000
PIN_MAX = 999999
PIN_LENGTH = 6

# Secrets (Manage via `wrangler secret put ADMIN_PINCODE`)
# ADMIN_PINCODE = "999999"
```

### 6.2 Types & Data Models (`src/types.ts`)
```typescript
export interface Env {
  DB: D1Database;
  STORAGE: R2Bucket;
  ADMIN_PINCODE: string;
  CORS_ALLOW_ORIGIN?: string;
  PIN_MIN?: string | number;
  PIN_MAX?: string | number;
  PIN_LENGTH?: string | number;
}

/**
 * Unified Database Row in D1 SQLite
 * Reference: skills/new_users_profile_and_approve.txt (Extended with required fields)
 */
export interface UserProfileRow {
  users_id: string;
  password: string;
  users_name: string;
  line_uid: string | null;
  display_name: string | null;
  emp_no: string | null;
  email: string | null;
  pc_limit: number;
  avatar_url: string | null;
  active: 'Y' | 'N';
  screen_tags: string;   // JSON array string in SQLite: '["PC01","PC02"]'
  approve_tags: string;  // JSON array string in SQLite: '["คุมวงเงินสด","อนุมัติวงเงินสด"]'
  created_at: string;
  updated_at: string;
}

/**
 * Backward & Modern Compatible DTO for Frontend
 */
export interface UserListItemDTO {
  users_id: string;
  users_name: string;
  Request_Name: string;            // Backward compatibility
  emp_no: string;
  email: string;
  pc_limit: number;                // Preserved from old system
  line_uid: string;
  display_name: string;
  displayName: string;             // Backward compatibility alias
  avatar_url: string;
  active: 'Y' | 'N';
  isPending: boolean;
  status: 'PENDING' | 'REGISTERED';
  screen_tags: string[];           // Parsed JSON array
  approve_tags: string[];          // Parsed JSON array
  pettycash_control: 'YES' | 'NO'; // Derived from approve_tags.includes('คุมวงเงินสด')
  pettycash_approve: 'YES' | 'NO'; // Derived from approve_tags.includes('อนุมัติวงเงินสด')
  can_approve: boolean;            // Derived from approve_tags.includes('อนุมัติวงเงินสด')
}

export interface ApiResponse<T = any> {
  success: boolean;
  message?: string;
  data?: T;
  role?: 'ADMIN' | 'USER';
  isPending?: boolean;
  usersList?: UserListItemDTO[];
  tag?: string;
}
```

### 6.3 Business Utilities & Crypto PIN Generator (`src/utils.ts`)
```typescript
export const Utils = {
  isPendingPin(val: string | null | undefined): boolean {
    if (!val) return false;
    const str = String(val).trim();
    return /^\d{6}$/.test(str);
  },

  normalizeName(name: string | null | undefined): string {
    if (!name) return '';
    return String(name).trim().toLowerCase().replace(/\s+/g, ' ');
  },

  sanitizeString(val: any): string {
    if (val === null || val === undefined) return '';
    return String(val).trim();
  },

  safeParseJsonArray(jsonStr: string | null | undefined): string[] {
    if (!jsonStr) return [];
    try {
      const parsed = JSON.parse(jsonStr);
      return Array.isArray(parsed) ? parsed.map(String) : [];
    } catch {
      return [];
    }
  },

  generateUserId(): string {
    const randomHex = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `USR-${Date.now().toString(36).toUpperCase()}-${randomHex}`;
  },

  /**
   * Cryptographically secure 6-digit PIN generator with collision detection against users_profile
   */
  async generateUniquePin(db: D1Database, adminPin: string): Promise<string> {
    const existingPins = new Set<string>();
    if (adminPin) existingPins.add(adminPin.trim());

    // Fetch existing pending PINs from users_profile (active = 'N' or length(password) = 6)
    const pendingUsers = await db
      .prepare(`
        SELECT password, line_uid 
        FROM users_profile 
        WHERE active = 'N' OR length(password) = 6 OR length(line_uid) = 6
      `)
      .all<{ password: string; line_uid: string }>();

    pendingUsers.results?.forEach(r => {
      if (r.password && r.password.length === 6) existingPins.add(r.password.trim());
      if (r.line_uid && r.line_uid.length === 6) existingPins.add(r.line_uid.trim());
    });

    const maxAttempts = 50;
    const array = new Uint32Array(1);

    for (let i = 0; i < maxAttempts; i++) {
      crypto.getRandomValues(array);
      const randomNum = 100000 + (array[0] % 900000);
      const pinStr = String(randomNum);

      if (!existingPins.has(pinStr)) {
        return pinStr;
      }
    }

    throw new Error('ไม่สามารถสุ่ม PIN ที่ไม่ซ้ำได้ (เกินจำนวนรอบสูงสุด 50 รอบ) กรุณาลองใหม่อีกครั้ง');
  }
};
```

### 6.4 User Service (`src/services/user.service.ts`)
```typescript
import { Env, UserProfileRow, UserListItemDTO, ApiResponse } from '../types';
import { Utils } from '../utils';

export class UserService {
  constructor(private env: Env) {}

  /**
   * List all users from unified users_profile table
   */
  async listUsers(): Promise<ApiResponse<UserListItemDTO[]>> {
    const db = this.env.DB;
    const res = await db.prepare("SELECT * FROM users_profile ORDER BY created_at DESC").all<UserProfileRow>();
    const users = res.results || [];

    const list: UserListItemDTO[] = users.map(user => {
      const rawUid = String(user.line_uid || '').trim();
      const rawPwd = String(user.password || '').trim();
      const isActive = user.active === 'Y';
      const isPending = !isActive || Utils.isPendingPin(rawUid) || Utils.isPendingPin(rawPwd);
      
      const screenTags = Utils.safeParseJsonArray(user.screen_tags);
      const approveTags = Utils.safeParseJsonArray(user.approve_tags);

      const hasControl = approveTags.includes('คุมวงเงินสด');
      const hasApprove = approveTags.includes('อนุมัติวงเงินสด');

      return {
        users_id: user.users_id,
        users_name: user.users_name || '',
        Request_Name: user.users_name || '',
        emp_no: user.emp_no || '',
        email: user.email || '',
        pc_limit: Number(user.pc_limit) || 0,
        line_uid: rawUid || (isPending && Utils.isPendingPin(rawPwd) ? rawPwd : ''),
        display_name: user.display_name || '',
        displayName: user.display_name || user.users_name || '',
        avatar_url: user.avatar_url || '',
        active: user.active,
        isPending,
        status: isPending ? 'PENDING' : 'REGISTERED',
        screen_tags: screenTags,
        approve_tags: approveTags,
        pettycash_control: hasControl ? 'YES' : 'NO',
        pettycash_approve: hasApprove ? 'YES' : 'NO',
        can_approve: hasApprove
      };
    });

    return { success: true, data: list };
  }

  /**
   * Create new user in unified table with tags and pc_limit
   */
  async createUser(payload: any): Promise<ApiResponse> {
    const db = this.env.DB;
    const reqName = Utils.sanitizeString(payload.users_name || payload.Request_Name || payload.request_name);
    const empNo = Utils.sanitizeString(payload.emp_no);
    const email = Utils.sanitizeString(payload.email);
    const pcLimit = Number(payload.pc_limit || payload['pc.limit'] || 0);

    if (!reqName) {
      return { success: false, message: 'กรุณาระบุชื่อผู้ใช้ (users_name หรือ Request_Name)' };
    }

    // 1. Check uniqueness of users_name
    const existing = await db
      .prepare("SELECT users_id FROM users_profile WHERE users_name = ? COLLATE NOCASE")
      .bind(reqName)
      .first();

    if (existing) {
      return { success: false, message: 'ชื่อนี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น' };
    }

    // 2. Build Screen & Approve Tags (Handling both new tag arrays and legacy switches)
    let screenTags: string[] = [];
    if (Array.isArray(payload.screen_tags)) {
      screenTags = payload.screen_tags.map(String);
    } else {
      screenTags = ["PC01"];
    }

    let approveTags: string[] = [];
    if (Array.isArray(payload.approve_tags)) {
      approveTags = payload.approve_tags.map(String);
    } else {
      const isControl = String(payload.pettycash_control || 'NO').toUpperCase() === 'YES';
      const canApprove = payload.can_approve === true || String(payload.can_approve || '').toUpperCase() === 'YES';
      if (isControl) approveTags.push('คุมวงเงินสด');
      if (canApprove) approveTags.push('อนุมัติวงเงินสด');
    }

    // 3. Generate unique user_id and 6-digit PIN
    const userId = Utils.sanitizeString(payload.users_id) || Utils.generateUserId();
    const newPin = await Utils.generateUniquePin(db, this.env.ADMIN_PINCODE);

    // 4. Single-table insert with Audit Log
    await db.batch([
      db.prepare(`
        INSERT INTO users_profile (
          users_id, password, users_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
        ) VALUES (?1, ?2, ?3, '', '', ?4, ?5, ?6, '', 'N', ?7, ?8)
      `).bind(
        userId,
        newPin,
        reqName,
        empNo,
        email,
        pcLimit,
        JSON.stringify(screenTags),
        JSON.stringify(approveTags)
      ),
      db.prepare(`
        INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
        VALUES ('CREATE_USER', 'ADMIN', ?1, ?2)
      `).bind(userId, JSON.stringify({ pin: newPin, users_name: reqName, empNo, pcLimit, screenTags, approveTags }))
    ]);

    return {
      success: true,
      message: 'เพิ่มผู้ใช้ใหม่สำเร็จ',
      data: {
        pin: newPin,
        users_id: userId,
        users_name: reqName,
        Request_Name: reqName,
        emp_no: empNo,
        email: email,
        pc_limit: pcLimit,
        screen_tags: screenTags,
        approve_tags: approveTags,
        pettycash_control: approveTags.includes('คุมวงเงินสด') ? 'YES' : 'NO',
        can_approve: approveTags.includes('อนุมัติวงเงินสด')
      }
    };
  }

  /**
   * Update existing user in unified table
   */
  async updateUser(payload: any): Promise<ApiResponse> {
    const db = this.env.DB;
    const targetId = Utils.sanitizeString(payload.users_id);
    const targetUid = Utils.sanitizeString(payload.target_line_uid || payload.line_uid);
    const newName = Utils.sanitizeString(payload.users_name || payload.Request_Name);
    const empNo = Utils.sanitizeString(payload.emp_no);
    const email = Utils.sanitizeString(payload.email);
    const pcLimit = payload.pc_limit !== undefined ? Number(payload.pc_limit) : undefined;

    if (!targetId && !targetUid) {
      return { success: false, message: 'ไม่พบรหัสผู้ใช้ที่ต้องการแก้ไข' };
    }
    if (!newName) {
      return { success: false, message: 'กรุณาระบุชื่อผู้ใช้ (users_name)' };
    }

    // Locate current user
    const userRow = await db
      .prepare(`
        SELECT * FROM users_profile 
        WHERE users_id = ?1 OR line_uid = ?2 OR password = ?2 OR users_name = ?3 COLLATE NOCASE
      `)
      .bind(targetId, targetUid, newName)
      .first<UserProfileRow>();

    if (!userRow) {
      return { success: false, message: 'ไม่พบข้อมูลผู้ใช้ในระบบ' };
    }

    // Check unique name if changed
    if (Utils.normalizeName(newName) !== Utils.normalizeName(userRow.users_name)) {
      const duplicate = await db
        .prepare("SELECT users_id FROM users_profile WHERE users_name = ?1 COLLATE NOCASE AND users_id != ?2")
        .bind(newName, userRow.users_id)
        .first();

      if (duplicate) {
        return { success: false, message: 'ชื่อนี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น' };
      }
    }

    // Regenerate PIN logic if pending
    let newPassword = userRow.password;
    let generatedPin: string | null = null;
    if (payload.regenerate_pin && userRow.active === 'N') {
      generatedPin = await Utils.generateUniquePin(db, this.env.ADMIN_PINCODE);
      newPassword = generatedPin;
    }

    // Process Tags
    let screenTags: string[];
    if (Array.isArray(payload.screen_tags)) {
      screenTags = payload.screen_tags.map(String);
    } else {
      screenTags = Utils.safeParseJsonArray(userRow.screen_tags);
    }

    let approveTags: string[];
    if (Array.isArray(payload.approve_tags)) {
      approveTags = payload.approve_tags.map(String);
    } else if (payload.pettycash_control !== undefined || payload.can_approve !== undefined) {
      approveTags = [];
      const isControl = String(payload.pettycash_control || 'NO').toUpperCase() === 'YES';
      const canApprove = payload.can_approve === true || String(payload.can_approve || '').toUpperCase() === 'YES';
      if (isControl) approveTags.push('คุมวงเงินสด');
      if (canApprove) approveTags.push('อนุมัติวงเงินสด');
    } else {
      approveTags = Utils.safeParseJsonArray(userRow.approve_tags);
    }

    const finalPcLimit = pcLimit !== undefined ? pcLimit : userRow.pc_limit;

    await db.batch([
      db.prepare(`
        UPDATE users_profile
        SET users_name = ?1,
            emp_no = ?2,
            email = ?3,
            pc_limit = ?4,
            password = ?5,
            screen_tags = ?6,
            approve_tags = ?7,
            updated_at = datetime('now')
        WHERE users_id = ?8
      `).bind(
        newName,
        empNo,
        email,
        finalPcLimit,
        newPassword,
        JSON.stringify(screenTags),
        JSON.stringify(approveTags),
        userRow.users_id
      ),
      db.prepare(`
        INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
        VALUES ('UPDATE_USER', 'ADMIN', ?1, ?2)
      `).bind(userRow.users_id, JSON.stringify({ users_name: newName, empNo, email, pcLimit: finalPcLimit, regeneratedPin: !!generatedPin }))
    ]);

    return {
      success: true,
      message: 'บันทึกการแก้ไขข้อมูลสำเร็จ',
      data: generatedPin ? { pin: generatedPin, users_name: newName } : null
    };
  }

  /**
   * Delete user from unified table
   */
  async deleteUser(identifier: string): Promise<ApiResponse> {
    const db = this.env.DB;
    const target = Utils.sanitizeString(identifier);
    if (!target) {
      return { success: false, message: 'ไม่พบรหัสผู้ใช้ที่ต้องการลบ' };
    }

    const userRow = await db
      .prepare("SELECT * FROM users_profile WHERE users_id = ?1 OR line_uid = ?1 OR password = ?1")
      .bind(target)
      .first<UserProfileRow>();

    if (!userRow) {
      return { success: false, message: 'ไม่พบข้อมูลผู้ใช้ในระบบ' };
    }

    await db.batch([
      db.prepare("DELETE FROM users_profile WHERE users_id = ?").bind(userRow.users_id),
      db.prepare("INSERT INTO audit_logs (action, performed_by, target_identifier) VALUES ('DELETE_USER', 'ADMIN', ?)")
        .bind(userRow.users_name)
    ]);

    return {
      success: true,
      message: 'ลบผู้ใช้เรียบร้อยแล้ว'
    };
  }

  /**
   * Query approvers dynamically by tag using SQLite JSON1
   */
  async getApproversByTag(tag: string): Promise<ApiResponse> {
    const db = this.env.DB;
    const cleanTag = Utils.sanitizeString(tag);
    if (!cleanTag) {
      return { success: false, message: 'กรุณาระบุ Tag ที่ต้องการค้นหา' };
    }

    const res = await db.prepare(`
      SELECT u.users_id, u.users_name, u.emp_no, u.pc_limit, u.line_uid, u.display_name, u.email, u.screen_tags, u.approve_tags
      FROM users_profile u, json_each(u.approve_tags) j
      WHERE u.active = 'Y' AND j.value = ?
    `).bind(cleanTag).all<UserProfileRow>();

    const users = (res.results || []).map(u => ({
      users_id: u.users_id,
      users_name: u.users_name,
      emp_no: u.emp_no || '',
      pc_limit: Number(u.pc_limit) || 0,
      line_uid: u.line_uid || '',
      display_name: u.display_name || '',
      email: u.email || '',
      approve_tags: Utils.safeParseJsonArray(u.approve_tags)
    }));

    return {
      success: true,
      tag: cleanTag,
      data: users
    };
  }
}
```

### 6.5 Auth Service (`src/services/auth.service.ts`)
```typescript
import { Env, ApiResponse, UserProfileRow } from '../types';
import { Utils } from '../utils';
import { UserService } from './user.service';

export class AuthService {
  constructor(private env: Env) {}

  /**
   * Verify entered PIN (ADMIN_PINCODE checked first, then pending User PIN in users_profile)
   */
  async verifyPin(pin: string): Promise<ApiResponse> {
    const inputPin = Utils.sanitizeString(pin);
    if (!inputPin) {
      return { success: false, message: 'กรุณากรอกรหัส PIN' };
    }

    const adminPin = String(this.env.ADMIN_PINCODE || '').trim();

    // 1. Check against ADMIN_PINCODE first
    if (adminPin && inputPin === adminPin) {
      const userService = new UserService(this.env);
      const listRes = await userService.listUsers();

      return {
        success: true,
        role: 'ADMIN',
        message: 'เข้าสู่ระบบผู้ดูแลระบบสำเร็จ',
        usersList: listRes.data || []
      };
    }

    // 2. Check against pending users in users_profile
    if (Utils.isPendingPin(inputPin)) {
      const userRow = await this.env.DB
        .prepare(`
          SELECT * FROM users_profile 
          WHERE (password = ?1 OR line_uid = ?1) AND active = 'N'
        `)
        .bind(inputPin)
        .first<UserProfileRow>();

      if (userRow) {
        const approveTags = Utils.safeParseJsonArray(userRow.approve_tags);
        const screenTags = Utils.safeParseJsonArray(userRow.screen_tags);

        return {
          success: true,
          role: 'USER',
          isPending: true,
          data: {
            usersId: userRow.users_id,
            requestName: userRow.users_name || '',
            usersName: userRow.users_name || '',
            empNo: userRow.emp_no || '',
            pcLimit: Number(userRow.pc_limit) || 0,
            email: userRow.email || '',
            screenTags: screenTags,
            approveTags: approveTags,
            pettycashControl: approveTags.includes('คุมวงเงินสด') ? 'YES' : 'NO'
          },
          message: 'พบข้อมูลผู้ใช้ พร้อมทำการลงทะเบียน'
        };
      }
    }

    // 3. Generic Error to prevent enumeration
    return {
      success: false,
      message: 'รหัสไม่ถูกต้อง'
    };
  }

  /**
   * Bind real LINE UID into unified users_profile and activate user
   */
  async registerUser(matchedPin: string, lineUid: string, displayName: string, pictureUrl?: string): Promise<ApiResponse> {
    const pin = Utils.sanitizeString(matchedPin);
    const uid = Utils.sanitizeString(lineUid);
    const name = Utils.sanitizeString(displayName);
    const pic = Utils.sanitizeString(pictureUrl);

    if (!pin || !uid) {
      return { success: false, message: 'ข้อมูลไม่ครบถ้วน (ต้องระบุ PIN และ LINE UID)' };
    }

    const db = this.env.DB;

    // Find pending user
    const userRow = await db
      .prepare(`
        SELECT * FROM users_profile 
        WHERE (password = ?1 OR line_uid = ?1) AND active = 'N'
      `)
      .bind(pin)
      .first<UserProfileRow>();

    if (!userRow) {
      return {
        success: false,
        message: 'ไม่พบรายการผู้ใช้ที่รอลงทะเบียนด้วยรหัส PIN นี้ (อาจมีการลงทะเบียนไปแล้ว)'
      };
    }

    // Update unified users_profile and record audit log
    await db.batch([
      db.prepare(`
        UPDATE users_profile
        SET line_uid = ?1,
            display_name = ?2,
            avatar_url = CASE WHEN ?3 != '' THEN ?3 ELSE avatar_url END,
            active = 'Y',
            updated_at = datetime('now')
        WHERE users_id = ?4
      `).bind(uid, name, pic, userRow.users_id),

      db.prepare(`
        INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
        VALUES ('REGISTER_USER', ?1, ?2, ?3)
      `).bind(uid, userRow.users_name, JSON.stringify({ displayName: name, avatarUrl: pic, previousPin: pin }))
    ]);

    return {
      success: true,
      message: 'ยืนยันตัวตนสำเร็จ',
      data: {
        lineUid: uid,
        displayName: name,
        usersName: userRow.users_name,
        requestName: userRow.users_name
      }
    };
  }
}
```

### 6.6 Main Worker Router & CORS Gateway (`src/index.ts`)
```typescript
import { Env, ApiResponse } from './types';
import { AuthService } from './services/auth.service';
import { UserService } from './services/user.service';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // 1. Handle CORS Preflight
    const origin = request.headers.get('Origin') || '*';
    const corsHeaders = {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
      'Access-Control-Max-Age': '86400',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    const json = (data: ApiResponse, status = 200) => {
      return new Response(JSON.stringify(data), {
        status,
        headers: {
          'Content-Type': 'application/json;charset=utf-8',
          ...corsHeaders
        }
      });
    };

    try {
      // -----------------------------------------------------------------------
      // Ping / Health Check
      // -----------------------------------------------------------------------
      if (request.method === 'GET' && (path === '/' || path === '/ping')) {
        return json({
          success: true,
          message: 'SmartBill Users Admin Worker (Unified D1 + R2) is operational.',
          data: { timestamp: new Date().toISOString(), version: '3.1.0-cf' }
        });
      }

      // -----------------------------------------------------------------------
      // Universal Action Router (100% Backwards Compatible with Existing Frontend)
      // -----------------------------------------------------------------------
      if (request.method === 'POST') {
        let payload: any = {};
        const contentType = request.headers.get('content-type') || '';

        if (contentType.includes('application/json') || contentType.includes('text/plain')) {
          const bodyText = await request.text();
          try {
            payload = JSON.parse(bodyText);
          } catch (e) {
            return json({ success: false, message: 'Invalid JSON payload format' }, 400);
          }
        }

        const action = payload.action || url.searchParams.get('action');

        if (!action) {
          return json({ success: false, message: 'Missing "action" parameter in request' }, 400);
        }

        const authService = new AuthService(env);
        const userService = new UserService(env);

        switch (action) {
          case 'verifyPin':
            return json(await authService.verifyPin(payload.pin));

          case 'registerUser':
            return json(await authService.registerUser(
              payload.pin || payload.matchedPin,
              payload.line_uid || payload.lineUid,
              payload.displayName || payload.line_profile,
              payload.pictureUrl || payload.avatar_url
            ));

          case 'listUsers':
            return json(await userService.listUsers());

          case 'createUser':
            return json(await userService.createUser(payload));

          case 'updateUser':
            return json(await userService.updateUser(payload));

          case 'deleteUser':
            return json(await userService.deleteUser(
              payload.users_id || payload.line_uid || payload.target_line_uid
            ));

          case 'getApprovers':
          case 'listApprovers':
            return json(await userService.getApproversByTag(payload.tag));

          default:
            return json({ success: false, message: `Unknown action: "${action}"` }, 404);
        }
      }

      // Support GET queries e.g. GET /api?action=listUsers or GET /api?action=getApprovers&tag=คุมวงเงินสด
      if (request.method === 'GET') {
        const action = url.searchParams.get('action');
        const userService = new UserService(env);

        if (action === 'listUsers') {
          return json(await userService.listUsers());
        }
        if (action === 'getApprovers') {
          return json(await userService.getApproversByTag(url.searchParams.get('tag') || ''));
        }
      }

      return json({ success: false, message: `Route not found: ${request.method} ${path}` }, 404);

    } catch (err: any) {
      console.error('Worker Uncaught Error:', err);
      return json({
        success: false,
        message: 'Internal Server Error: ' + (err.message || 'Unknown error occurred')
      }, 500);
    }
  }
};
```

---

## 7. Data Migration Runbook (ETL from Google Sheets to Cloudflare D1 Unified Schema)

```
+---------------------------+       CSV Export       +-----------------------------+
|    Google Spreadsheet     | ---------------------> |   Unified ETL Sanitizer     |
| - users_profile.csv       |                        |   (Merge 2 sheets into 1,   |
| - Approve_Users.csv       |                        |    pc_limit, tags, profile) |
+---------------------------+                        +-----------------------------+
                                                                    |
                                                                    v
                                                     +-----------------------------+
                                                     |    Generated SQL Seed File  |
                                                     |    seed_data.sql            |
                                                     +-----------------------------+
                                                                    |
                                                                    v  wrangler d1 execute
                                                     +-----------------------------+
                                                     |    Cloudflare D1 Database   |
                                                     |    (users_profile unified)  |
                                                     +-----------------------------+
```

### 7.1 Python ETL Extraction & Sanitization Script (`etl_migrate.py`)
```python
import csv
import json
import re

def clean_str(val):
    return val.strip() if val else ""

def generate_d1_seed():
    print("-- Starting ETL Generation for Cloudflare D1 (Unified users_profile) --")
    
    users_map = {}
    
    # 1. Read users_profile.csv
    # Expected columns: line_uid, Request_Name, emp_no, pc.limit, pettycash_control
    with open('users_profile.csv', mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader, 1):
            raw_uid = clean_str(row.get('line_uid', ''))
            req_name = clean_str(row.get('Request_Name', ''))
            emp_no = clean_str(row.get('emp_no', ''))
            try:
                pc_limit = float(row.get('pc.limit', 0))
            except:
                pc_limit = 0.0
            control = clean_str(row.get('pettycash_control', 'NO')).upper()
            
            if not req_name:
                continue

            user_id = f"USR-{str(i).zfill(4)}"
            is_pin = bool(re.match(r'^\d{6}$', raw_uid))
            
            # Map state
            active = 'N' if is_pin or not raw_uid else 'Y'
            password = raw_uid if is_pin else ''
            line_uid = '' if is_pin else raw_uid
            
            approve_tags = []
            if control == 'YES':
                approve_tags.append('คุมวงเงินสด')
                
            users_map[req_name.lower()] = {
                'users_id': user_id,
                'password': password,
                'users_name': req_name,
                'line_uid': line_uid,
                'display_name': '',
                'emp_no': emp_no,
                'email': '',
                'pc_limit': pc_limit,
                'avatar_url': '',
                'active': active,
                'screen_tags': ['PC01'],
                'approve_tags': approve_tags
            }

    # 2. Merge Approve_Users.csv into users_map
    # Expected columns: approve_request, line_profile, line_uid, pettycash_approve
    try:
        with open('Approve_Users.csv', mode='r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                app_req = clean_str(row.get('approve_request', ''))
                app_profile = clean_str(row.get('line_profile', ''))
                app_perm = clean_str(row.get('pettycash_approve', 'NO')).upper()
                app_uid = clean_str(row.get('line_uid', ''))
                
                if not app_req:
                    continue
                    
                key = app_req.lower()
                if key in users_map:
                    target = users_map[key]
                    if app_perm == 'YES' and 'อนุมัติวงเงินสด' not in target['approve_tags']:
                        target['approve_tags'].append('อนุมัติวงเงินสด')
                    if app_profile and not re.match(r'^\d{6}$', app_profile):
                        target['display_name'] = app_profile
                    if not target['line_uid'] and app_uid and not re.match(r'^\d{6}$', app_uid):
                        target['line_uid'] = app_uid
                        target['active'] = 'Y'
                else:
                    # New approver not found in users_profile
                    idx = len(users_map) + 1
                    user_id = f"USR-{str(idx).zfill(4)}"
                    is_pin = bool(re.match(r'^\d{6}$', app_uid))
                    users_map[key] = {
                        'users_id': user_id,
                        'password': app_uid if is_pin else '',
                        'users_name': app_req,
                        'line_uid': '' if is_pin else app_uid,
                        'display_name': app_profile if not re.match(r'^\d{6}$', app_profile) else '',
                        'emp_no': '',
                        'email': '',
                        'pc_limit': 0.0,
                        'avatar_url': '',
                        'active': 'N' if is_pin or not app_uid else 'Y',
                        'screen_tags': ['PC01'],
                        'approve_tags': ['อนุมัติวงเงินสด'] if app_perm == 'YES' else []
                    }
    except FileNotFoundError:
        print("Note: Approve_Users.csv not found, proceeding with users_profile data only.")

    # 3. Generate SQL Inserts
    sql_statements = []
    for item in users_map.values():
        screen_json = json.dumps(item['screen_tags'], ensure_ascii=False)
        approve_json = json.dumps(item['approve_tags'], ensure_ascii=False)
        
        sql = (
            f"INSERT OR REPLACE INTO users_profile ("
            f"users_id, password, users_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags"
            f") VALUES ("
            f"'{item['users_id']}', '{item['password']}', '{item['users_name']}', '{item['line_uid']}', "
            f"'{item['display_name']}', '{item['emp_no']}', '{item['email']}', {item['pc_limit']}, "
            f"'{item['avatar_url']}', '{item['active']}', '{screen_json}', '{approve_json}');"
        )
        sql_statements.append(sql)

    with open('seed_data.sql', 'w', encoding='utf-8') as out:
        out.write("BEGIN TRANSACTION;
")
        out.write("
".join(sql_statements) + "
")
        out.write("COMMIT;
")
        
    print(f"Successfully generated seed_data.sql with {len(sql_statements)} unified user records.")

if __name__ == '__main__':
    generate_d1_seed()
```

---

## 8. Deployment & Cutover Checklist

### 8.1 Deployment Commands
```bash
# 1. Login to Cloudflare
npx wrangler login

# 2. Create Cloudflare D1 Database
npx wrangler d1 create smartbill-prod-db
# Copy database_id into wrangler.toml

# 3. Create Cloudflare R2 Bucket
npx wrangler r2 bucket create smartbill-assets

# 4. Initialize Database Schema (DDL)
npx wrangler d1 execute smartbill-prod-db --file=./src/db/schema.sql

# 5. Seed Migrated Data from Sheets
npx wrangler d1 execute smartbill-prod-db --file=./seed_data.sql

# 6. Set Production Secrets
npx wrangler secret put ADMIN_PINCODE
# Enter value e.g. 999999

# 7. Deploy Worker to Cloudflare Edge
npx wrangler deploy
```

### 8.2 Frontend Cutover (Single-Line Configuration Update)
แก้ไขไฟล์ `js/config.js` ในฝั่ง Client:

```javascript
// BEFORE (Legacy Google Apps Script Web App)
// const GAS_WEB_APP_URL = "https://script.google.com/macros/s/AKfycbzResnXlQ3FNOtlXepfjLMtPIKETxzqedKEqQ3nOvZ06AvQYDYn-W5yZ5b7sJ4dhAld/exec";

// AFTER (Cloudflare Worker API Gateway - Unified Architecture)
const GAS_WEB_APP_URL = "https://smartbill-usersadmin-api.<your-subdomain>.workers.dev/api";
const LIFF_ID = "2009016720-7Bu2JHRK";
const APP_VERSION = "v3.1.0-cf";
```

### 8.3 Functional Verification Matrix (Smoke Test)
* [ ] **Test 1: Admin Login** — กรอก `ADMIN_PINCODE` -> ต้องเข้าหน้า Admin Dashboard ได้ทันที, ข้อมูลสถิติและตารางแสดงครบถ้วน
* [ ] **Test 2: Create User with PettyCash Control = YES & pc_limit** — เพิ่มผู้ใช้ใหม่พร้อมวงเงิน -> ตรวจสอบว่าได้ PIN 6 หลัก, ตาราง `users_profile` บันทึก `pc_limit` และ `approve_tags` เป็น `["คุมวงเงินสด"]`
* [ ] **Test 3: Create User without PettyCash Control & can_approve = YES** — ตรวจสอบว่าใน `users_profile` บันทึก `approve_tags` เป็น `["อนุมัติวงเงินสด"]`
* [ ] **Test 4: Create User with Screen Tags** — เพิ่มผู้ใช้พร้อมกำหนด `screen_tags = ["PC01", "PC02"]` -> ข้อมูลบันทึกถูกต้อง
* [ ] **Test 5: Unique Users_Name Rejection** — ทดลองสร้าง User ชื่อซ้ำ -> ต้องได้รับข้อความ `"ชื่อนี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น"`
* [ ] **Test 6: User LIFF Registration** — กรอก PIN 6 หลักของ Pending User -> หน้าจอแสดงข้อมูลวงเงิน `pcLimit` ถูกต้อง -> กดลงทะเบียน -> `line_uid` เปลี่ยนเป็น LINE UID จริง, `display_name` ได้รับการบันทึก และ `active` เปลี่ยนเป็น `'Y'`
* [ ] **Test 7: Regenerate PIN** — กดแก้ไข Pending User แล้วเลือกขอ PIN ใหม่ -> ต้องได้ PIN 6 หลักใหม่ และฟิลด์ `password` อัปเดตตรงกัน
* [ ] **Test 8: Query Approvers by Tag (New API)** — เรียก Action `getApprovers` ด้วย tag `"คุมวงเงินสด"` และ `"อนุมัติวงเงินสด"` -> ได้รายชื่อผู้อนุมัติพร้อมวงเงิน `pc_limit` ถูกต้องแม่นยำ
* [ ] **Test 9: Delete User** — ลบผู้ใช้ -> ตรวจสอบว่าข้อมูลใน `users_profile` ถูกลบออกอย่างสมบูรณ์ใน single query
