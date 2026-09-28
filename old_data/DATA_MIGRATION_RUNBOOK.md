# คู่มือขั้นตอนการย้ายข้อมูล (Data Migration Runbook)
## สำหรับระบบ SmartBill Users Admin (Go-Live Step-by-Step Guide)

> **เอกสารนี้จัดทำขึ้นสำหรับ:** ผู้ดูแลระบบ (Admin) หรือทีม DevOps/Developer ที่จะทำการย้ายข้อมูลจริง ณ วันที่ระบบพร้อม **Go-Live**  
> **วัตถุประสงค์:** ป้องกันการตกหล่น ลืมขั้นตอน หรือนำเข้าข้อมูลผิดพลาด โดยมีคำสั่งและขั้นตอนตรวจสอบครบถ้วนในที่เดียว

---

## 📌 สรุปภาพรวมกระบวนการ (Migration Flowchart)

```
[Google Sheets / ระบบเดิม]
          │
          ▼  1. ดาวน์โหลดเป็นไฟล์ Excel ล่าสุด
[Billing_data.xlsx] ──► วางทับที่โฟลเดอร์ old_data/
          │
          ▼  2. รันคำสั่งแปลงข้อมูล (ETL)
[npm run migrate:etl] (หรือ python old_data/migrate_etl.py)
          │
          ├──► สร้าง old_data/migrated_users.sql (สำหรับรัน Local)
          ├──► สร้าง old_data/cloud_migration_schema.sql (ขยาย Schema บน Cloud D1 โดยไม่ลบตาราง)
          ├──► สร้าง old_data/cloud_migrated_users.sql (UPSERT ขึ้น Cloud โดยรักษาข้อมูลรถเดิม)
          └──► สร้าง old_data/migrated_users.json (สรุปข้อมูลตรวจสอบ)
          │
          ▼  3. ทดสอบนำเข้าที่ Local ก่อนเสมอ (Zero Risk Sandbox)
[npm run migrate:local] ──► ตรวจสอบด้วย [npm test]
          │
          ▼  4. นำเข้าขึ้นระบบจริงบน Cloudflare D1 (IMG_DB)
[ตั้งค่า Account ID]   ──► $env:CLOUDFLARE_ACCOUNT_ID = "f9bc011eeec351846c11f6aefacded76"
[สำรองข้อมูลก่อนรัน]   ──► npx wrangler d1 export IMG_DB --remote --output=old_data/backup.sql
[npm run cloud:schema]  ──► ขยายโครงสร้างตาราง (In-Place Alter ไม่ลบตาราง)
[npm run cloud:migrate] ──► ผสานข้อมูล SmartBill + ซิงค์ผู้อนุมัติ (UPSERT)
[npm run cloud:verify]  ──► ตรวจสอบความถูกต้องของสถิติและข้อมูลรถ
          │
          ▼  5. Deploy Web Application
[npm run deploy]        ──► เผยแพร่ Worker + หน้าเว็บ Admin ขึ้น Cloudflare Edge
```

---

## 📋 ข้อมูลระบบ Cloudflare Production ปลายทาง

| รายการ | ค่าที่กำหนด | คำอธิบาย |
|---|---|---|
| **Cloudflare Account ID** | `f9bc011eeec351846c11f6aefacded76` | บัญชี `Pingly69@gmail.com's Account` |
| **Database Name** | `IMG_DB` | ฐานข้อมูลกลาง (Cloudflare D1) |
| **Database ID** | `4db03e65-cc9d-458e-81f7-b8119669dd17` | รหัสอ้างอิงของ D1 บน Cloudflare |
| **Binding Name** | `DB` | ตัวแปร Binding ที่ Worker เรียกใช้ |
| **Target Table** | `users_profile` | ตารางข้อมูลพนักงานและวงเงิน |
| **Primary Key** | `line_uid` (TEXT) | รหัส LINE UID ของผู้ใช้งาน |
| **Standard Name Field**| `requester_name` (TEXT) | ฟิลด์ชื่อพนักงานมาตรฐานตามฐานข้อมูล Cloud |

---

## 📋 เช็คลิสต์สิ่งที่ต้องเตรียมก่อนเริ่ม (Pre-requisites)

- [ ] ติดตั้ง **Python 3.8+** พร้อมโมดูล `openpyxl` (ติดตั้งด้วย `pip install openpyxl`)
- [ ] ติดตั้ง **Node.js 18+** และเครื่องมือพร้อมใช้งาน
- [ ] ติดตั้ง **Wrangler CLI** (`npm install` ในโปรเจกต์)
- [ ] สิทธิ์ล็อกอิน Cloudflare (`npx wrangler whoami`)
- [ ] มีไฟล์ Excel ข้อมูลล่าสุดที่มีชีต `users_profile` และ `Approve_users`

---

## 🚀 ขั้นตอนการปฏิบัติการจริง (5 ขั้นตอนจบ)

### ขั้นตอนที่ 1: เตรียมไฟล์ข้อมูลล่าสุด (Prepare Latest Data)
1. ไปที่ Google Sheets ต้นฉบับของระบบเดิม
2. ทำการ Export หรือดาวน์โหลดเป็นไฟล์ **Microsoft Excel (.xlsx)**
3. เปลี่ยนชื่อไฟล์เป็น: **`Billing_data.xlsx`**
4. นำไฟล์มาวางทับที่โฟลเดอร์:
   ```
   SmartBill_usersadmin_v3/old_data/Billing_data.xlsx
   ```
   *(หมายเหตุ: ต้องมั่นใจว่าในไฟล์มี 2 ชีตชื่อ `users_profile` และ `Approve_users`)*

---

### ขั้นตอนที่ 2: รันสคริปต์ ETL รวมข้อมูล (Extract & Merge)
เปิด Terminal ในโฟลเดอร์โปรเจกต์ แล้วรันคำสั่ง:

```bash
npm run migrate:etl
```
*(หรือรันตรงด้วย `python old_data/migrate_etl.py`)*

#### ตรรกะที่สคริปต์ทำงานให้อัตโนมัติ:
1. **รวม 2 ชีตให้เหลือ 1 คนต่อ 1 บรรทัด (Deduplication):** โดยจับคู่ผ่าน `line_uid` และชื่อพนักงาน
2. **แปลงสิทธิ์เป็น Tag-Based อัตโนมัติ:**
   * ถ้า `pettycash_approve = 'YES'` ในชีต `Approve_users` $\rightarrow$ ได้สิทธิ์ **`["อนุมัติวงเงินสด"]`**
   * ถ้า `pettycash_approve = 'NO'` หรือ `pettycash_control = 'YES'` $\rightarrow$ ได้สิทธิ์ **`["คุมวงเงินสด"]`**
   * ผู้ขอเบิกทั่วไปที่ไม่มีวงเงิน $\rightarrow$ กำหนดสิทธิ์ **`[]`**
3. **กำหนดชื่อฟิลด์มาตรฐาน:** ใช้ `requester_name` เป็นคอลัมน์หลักตามตารางจริงบน Cloud D1
4. **ดึงชื่อโปรไฟล์ LINE:** จากคอลัมน์ `line_profile` มาใส่ในฟิลด์ `display_name`
5. **ล้างรหัสพนักงาน:** แถวที่มีค่าเป็น `xxxxx` จะถูกเคลียร์เป็นค่าว่างให้สะอาด

#### สิ่งที่ต้องตรวจสอบหลังรันเสร็จ:
* ตารางสรุปบนหน้าจอ Terminal ต้องแสดงจำนวนคนถูกต้อง
* ไฟล์ผลลัพธ์ที่สร้างขึ้นอัตโนมัติ:
  * `old_data/migrated_users.sql` (สำหรับรัน Local D1)
  * `old_data/cloud_migration_schema.sql` (สำหรับเพิ่มฟิลด์บน Cloud D1)
  * `old_data/cloud_migrated_users.sql` (สำหรับ UPSERT ข้อมูลขึ้น Cloud D1)
  * `old_data/migrated_users.json` (ไฟล์ JSON ให้เปิดเช็คความเรียบร้อย)

---

### ขั้นตอนที่ 3: ทดสอบนำเข้าที่ Local ก่อนเสมอ (Local Staging Test)
เพื่อความปลอดภัย 100% **ห้ามนำขึ้นระบบจริงทันทีโดยไม่ผ่านขั้นตอนนี้**

1. สั่งรันนำเข้า SQL เข้าฐานข้อมูล Local D1:
   ```bash
   npm run migrate:local
   ```
2. รัน Automated Test เพื่อยืนยันว่าระบบทำงานได้สมบูรณ์:
   ```bash
   npm test
   ```
3. เปิดเบราว์เซอร์เข้าไปที่ `http://127.0.0.1:8787`:
   * ล็อกอินด้วย Admin PIN: `999999`
   * ตรวจสอบว่าจำนวนผู้ใช้ใน Dashboard เพิ่มขึ้นตรงกับไฟล์ Excel ล่าสุด
   * ตรวจสอบรายชื่อ, วงเงิน และปุ่มสวิตช์ผู้ถือเงินสด/ผู้อนุมัติว่าถูกต้อง

---

### ขั้นตอนที่ 4: นำเข้าข้อมูลขึ้นระบบจริงบน Cloudflare D1 (`IMG_DB`)

> [!CAUTION]
> **คำเตือนความปลอดภัยสูงสุด:** ตาราง `users_profile` บน Cloud `IMG_DB` มีข้อมูลผู้ใช้เดิมของระบบรถ/งานระบบอื่นอยู่แล้ว 50 รายการ **ห้ามรันคำสั่ง DROP TABLE หรือรัน `schema.sql` ทับเด็ดขาด** ให้ใช้ชุดคำสั่งที่เตรียมไว้ตามลำดับนี้เท่านั้น

#### 4.1 ตั้งค่า Account ID ใน Terminal (สำหรับ Windows PowerShell):
```powershell
$env:CLOUDFLARE_ACCOUNT_ID = "f9bc011eeec351846c11f6aefacded76"
```
*(ถ้าใช้ Command Prompt ทั่วไป ให้ใช้ `set CLOUDFLARE_ACCOUNT_ID=f9bc011eeec351846c11f6aefacded76`)*

#### 4.2 ทำการ Backup ข้อมูลเดิมก่อนเริ่มงาน (Safety First):
```powershell
npx wrangler d1 export IMG_DB --remote --output=./old_data/backup_before_migration.sql
```

#### 4.3 ขยายโครงสร้างตารางเดิมบน Cloud (In-Place Alter Table):
```powershell
npm run cloud:schema
```
*คำสั่งนี้จะรันไฟล์ `old_data/cloud_migration_schema.sql` เพื่อเพิ่ม 9 คอลัมน์ของ SmartBill (`users_id`, `password`, `display_name`, `email`, `pc_limit`, `avatar_url`, `active`, `screen_tags`, `approve_tags`) และสร้างตาราง `audit_logs` โดยไม่ลบตารางและไม่กระทบข้อมูลรถเดิมเลย*

#### 4.4 ผสานข้อมูล SmartBill และซิงค์สิทธิ์ผู้อนุมัติ (Safe Merge UPSERT):
```powershell
npm run cloud:migrate
```
*คำสั่งนี้จะรันไฟล์ `old_data/cloud_migrated_users.sql` เพื่อเพิ่ม/อัปเดตสิทธิ์คน SmartBill และคงข้อมูลรถ `car_no`, `group_car` ของคนเดิมไว้ 100%*

#### 4.5 ตรวจสอบความถูกต้องสมบูรณ์ (Verification):
```powershell
npm run cloud:verify
```
ผลลัพธ์ที่ได้ควรแสดง:
* `total_users`: รวมผู้ใช้ทั้งหมด (พนักงานเดิม + พนักงาน SmartBill)
* `users_with_limit`: จำนวนผู้ถือเงินสดย่อยที่มีวงเงิน > 0
* `approvers_count`: จำนวนผู้อนุมัติที่มี Tag

หรือตรวจสอบดูรายชื่อและข้อมูลรถได้ด้วย:
```powershell
npx wrangler d1 execute IMG_DB --remote --command="SELECT line_uid, requester_name, emp_no, car_no, pc_limit, approve_tags FROM users_profile WHERE pc_limit > 0 OR approve_tags != '[]';"
```

---

### ขั้นตอนที่ 5: Deploy ระบบ Web Application ขึ้น Cloudflare Edge
เมื่อฐานข้อมูลพร้อมแล้ว ให้ทำการ Deploy เวอร์ชันล่าสุดขึ้น Cloudflare Workers + Static Assets:

```powershell
npm run deploy
```

เมื่อเสร็จสิ้น Wrangler จะแสดง Production URL เช่น:
```
https://smartbill-usersadmin-api.pingly69.workers.dev
```
ให้เปิดทดสอบเข้าใช้งานผ่าน URL จริงด้วย Admin PIN `999999`

---

## 💡 กลไกความปลอดภัย: ทำไมรันซ้ำแล้วไม่พัง? (Idempotent UPSERT)

คำสั่ง SQL ที่สร้างขึ้นใช้กลไก **UPSERT** ของ SQLite:

```sql
INSERT INTO users_profile (
    line_uid, requester_name, users_id, password, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
) VALUES (...)
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
```

* **ถ้ายังไม่มีคนนี้ในระบบ:** จะทำการ `INSERT` รายชื่อใหม่เข้าไป
* **ถ้ามีคนนี้อยู่แล้ว (เช็คจาก `line_uid`):** จะทำการ `UPDATE` ข้อมูลชื่อ, วงเงิน และสิทธิ์ให้เป็นปัจจุบันทันที **โดยไม่แตะต้อง `car_no` และ `group_car` เดิม** ทำให้ข้อมูลของระบบรถไม่เสียหาย 100%
* **สำหรับผู้ใช้ที่ยังไม่ลงทะเบียน LINE:** สคริปต์จะใช้ `PENDING:USR-XXXX` เป็นรหัสชั่วคราวเพื่อไม่ให้ชนข้อจำกัด Primary Key

---

## 🛠️ การแก้ไขปัญหาที่อาจพบได้ (Troubleshooting)

| ปัญหา | สาเหตุ | วิธีแก้ไข |
|---|---|---|
| `More than one account found` | มีหลาย Cloudflare Account ในเครื่อง | รัน `$env:CLOUDFLARE_ACCOUNT_ID = "f9bc011eeec351846c11f6aefacded76"` ก่อนคำสั่ง wrangler |
| `Error: Excel file not found` | ไม่พบไฟล์ `Billing_data.xlsx` | ตรวจสอบว่านำไฟล์ไปวางไว้ที่โฟลเดอร์ `old_data/` และสะกดชื่อถูกต้อง |
| `UnicodeEncodeError: 'charmap'` | Terminal Windows ไม่รองรับภาษาไทย | สคริปต์มีคำสั่ง `sys.stdout.reconfigure(encoding='utf-8')` อยู่แล้ว หากยังพบ ให้ตั้งค่า Terminal ด้วยคำสั่ง `chcp 65001` |
| `Missing required sheets` | ชื่อชีตใน Excel ไม่ตรง | ตรวจสอบตัวพิมพ์เล็ก/ใหญ่ของชีตใน Excel ต้องเป็น `users_profile` และ `Approve_users` |
| รหัสพนักงานแสดงเป็น `xxxxx` | ข้อมูลเดิมในชีตใส่ค่าสมมุติไว้ | สคริปต์จะแปลงเป็นค่าว่างให้ทันที ไม่ต้องกังวล |
| วงเงินไม่แสดงทศนิยม | ตัวเลขในชีตไม่มีจุดทศนิยม | สคริปต์จัดรูปแบบเป็น `REAL` (ทศนิยม 2 ตำแหน่ง) ใน SQLite ให้อัตโนมัติ |

---

**จัดทำโดย:** Full Stack Development Team (Cloudflare D1 Migration Project)  
**เวอร์ชันเอกสาร:** 1.1.0 (Production & Sandbox Verified)
