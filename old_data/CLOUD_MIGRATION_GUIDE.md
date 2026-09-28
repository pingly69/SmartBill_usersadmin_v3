# แผนการย้ายข้อมูลขึ้น Cloudflare D1 (IMG_DB Migration Runbook)
## การรวมฐานข้อมูล users_profile โดยไม่กระทบข้อมูลเดิมของระบบอื่น (Zero-Downtime & Non-Destructive)

> **เอกสารนี้สำหรับ:** ทีมพัฒนาระบบ และ Database Administrator (DBA)  
> **ฐานข้อมูลเป้าหมายบน Cloud:** `IMG_DB` (Cloudflare D1 ID: `4db03e65-cc9d-458e-81f7-b8119669dd17`)  
> **หลักการสำคัญ:** **ห้ามลบตาราง (NO DROP TABLE)**, **ห้ามเขียนทับข้อมูลรถ (car_no, group_car)**, **และต้องคงความเข้ากันได้ 100% กับระบบเดิมที่ใช้งานอยู่**

---

## 🔍 1. การวิเคราะห์โครงสร้างฐานข้อมูลปัจจุบันบน Cloud (`IMG_DB`)

จากการตรวจสอบโครงสร้างตารางจริงบน Cloud D1 (`IMG_DB`):

### 1.1 ตารางปัจจุบัน: `users_profile` (มีข้อมูลผู้ใช้จริง 50 รายการ)
```sql
CREATE TABLE users_profile (
  line_uid          TEXT NOT NULL PRIMARY KEY,  -- LINE userId ตรวจสอบจาก LIFF
  requester_name    TEXT NOT NULL,              -- ชื่อผู้ขอเบิก (ตรงกับ SmartBill แล้ว)
  car_no            TEXT NOT NULL DEFAULT '',   -- ทะเบียนรถ (ของระบบเดิม ห้ามแตะต้อง!)
  group_car         INTEGER NOT NULL DEFAULT 1, -- กลุ่มอัตรา (ของระบบเดิม ห้ามแตะต้อง!)
  emp_no            TEXT NOT NULL DEFAULT '',   -- รหัสพนักงาน
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### 1.2 ตารางปัจจุบัน: `approve_users` (มีผู้อนุมัติเดิม 5 รายการ)
```sql
CREATE TABLE approve_users (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  approve_request  TEXT NOT NULL,
  line_profile     TEXT NOT NULL DEFAULT '',
  line_uid         TEXT NOT NULL DEFAULT '',
  active           INTEGER NOT NULL DEFAULT 1
);
```

---

## 🛡️ 2. กลยุทธ์ความปลอดภัย 5 ชั้น (5-Layer Safety Guarantee)

1. **ไม่ทำลายตารางเดิม (Non-Destructive Alteration):**  
   ใช้คำสั่ง `ALTER TABLE users_profile ADD COLUMN ...` เติมเฉพาะคอลัมน์ใหม่ที่ SmartBill ต้องการ โดย**ไม่ดรอปตาราง และไม่สร้างตารางใหม่** ข้อมูล 50 คนเดิมจะไม่สูญหายแม้แต่ไบต์เดียว
2. **ปกป้องข้อมูลยานพาหนะ (Preserve Vehicle & Route Info):**  
   คำสั่ง `UPSERT` ของ SmartBill อัปเดตเฉพาะฟิลด์วงเงินและสิทธิ์ (`pc_limit`, `approve_tags`, `screen_tags`) โดย**ละเว้นคอลัมน์ `car_no` และ `group_car` ไว้ ไม่แตะต้องเด็ดขาด**
3. **ป้องกัน Primary Key ชนกัน (Safe Pending User Identification):**  
   เนื่องจากตารางบน Cloud ใช้ `line_uid` เป็น Primary Key ผู้ใช้ใน SmartBill ที่ยังไม่ได้ผูก LINE (รอส่ง PIN) จะถูกกำหนด `line_uid` ชั่วคราวเป็น `'PENDING:' || users_id` (เช่น `PENDING:USR-MIG-0011`) เพื่อไม่ให้เกิด Error `UNIQUE constraint failed` จากค่าว่าง
4. **ซิงค์สิทธิ์ผู้อนุมัติเดิมอัตโนมัติ (Automated Approver Sync):**  
   สคริปต์จะค้นหารายชื่อจากตาราง `approve_users` เดิมบน Cloud แล้วเติม Tag `["อนุมัติวงเงินสด"]` ให้อัตโนมัติในตาราง `users_profile` ทันที
5. **ระบบ Audit Log ระดับ Enterprise:**  
   สร้างตาราง `audit_logs` บน Cloud และบันทึกประวัติทุกการ Migrate ไว้อย่างชัดเจน

---

## 🚀 3. ขั้นตอนการปฏิบัติการจริง (4 ขั้นตอน)

ก่อนเริ่ม ให้ตั้งค่า Account ID ของ Cloudflare ใน Terminal (หากมีหลาย Account):
```powershell
$env:CLOUDFLARE_ACCOUNT_ID = "f9bc011eeec351846c11f6aefacded76"
```

---

### ขั้นตอนที่ 1: ตรวจสอบและสำรองข้อมูลก่อนเริ่ม (Pre-flight Inspection)
รันคำสั่งตรวจสอบจำนวนแถวเดิมบน Cloud:
```bash
npx wrangler d1 execute IMG_DB --remote --command="SELECT count(*) as total_users FROM users_profile;"
```
*(ผลลัพธ์ปกติจะต้องได้ 50 users)*

---

### ขั้นตอนที่ 2: ขยายโครงสร้างตารางบน Cloud (Expand Schema)
รันสคริปต์ [old_data/cloud_migration_schema.sql](file:///c:/Antigravity_Data/SmartBill_usersadmin_v3/old_data/cloud_migration_schema.sql):
```bash
npm run cloud:schema
```
**สิ่งที่เกิดขึ้น:**
- เพิ่มคอลัมน์: `users_id`, `password`, `display_name`, `email`, `pc_limit`, `avatar_url`, `active`, `screen_tags`, `approve_tags`
- สร้างตาราง `audit_logs`
- สร้าง Indexes สำหรับค้นหาเร็ว
- ข้อมูลเดิมทั้ง 50 รายชื่อยังคงอยู่ครบ 100%

---

### ขั้นตอนที่ 3: ผสานข้อมูล SmartBill เข้ากับ Cloud (Merge Data via UPSERT)
รันสคริปต์ [old_data/cloud_migrated_users.sql](file:///c:/Antigravity_Data/SmartBill_usersadmin_v3/old_data/cloud_migrated_users.sql):
```bash
npm run cloud:migrate
```
**สิ่งที่เกิดขึ้น:**
- บุคลากร SmartBill ที่มี `line_uid` ตรงกับ Cloud (เช่น `ภาดล ทองดี`, `สุวัฒน์`, `นันทพงศ์`) จะได้รับการอัปเดตสิทธิ์ `pc_limit` และ `approve_tags` โดย**ข้อมูลรถ `car_no` ไม่ถูกแตะต้อง**
- บุคลากร SmartBill ใหม่จะถูกเพิ่มเข้าไปในระบบ
- ผู้อนุมัติเดิมในตาราง `approve_users` (เช่น `พี่น้ำ`, `พี่ดุ๋ย`, `พี่ลิขิต`, `สกุณา`) จะได้รับสิทธิ์ `อนุมัติวงเงินสด` อัตโนมัติ

---

### ขั้นตอนที่ 4: ตรวจสอบความถูกต้องสมบูรณ์ (Post-flight Verification)
รันคำสั่ง Verify รวม:
```bash
npm run cloud:verify
```
หรือรันคำสั่งดูตัวอย่างข้อมูลที่ผสานแล้ว:
```bash
npx wrangler d1 execute IMG_DB --remote --command="SELECT line_uid, requester_name, emp_no, car_no, group_car, pc_limit, approve_tags FROM users_profile WHERE approve_tags != '[]' LIMIT 10;"
```

**เกณฑ์การผ่าน (Checklist):**
- [ ] คอลัมน์ `car_no` ของคนเดิมยังอยู่เหมือนเดิม
- [ ] คอลัมน์ `pc_limit` และ `approve_tags` ของคนถือเงินสดแสดงค่าถูกต้อง
- [ ] ผู้อนุมัติมี Tag `["อนุมัติวงเงินสด"]`
- [ ] ไม่มี Error ในระบบเดิมที่เรียกใช้ตารางนี้

---

## 🔄 4. การ Rollback (กรณีฉุกเฉิน)
เนื่องจากเราใช้คำสั่ง `ADD COLUMN` พร้อมค่า Default ปลอดภัย และไม่ได้ลบคอลัมน์หรือแถวใดๆ:
- หากระบบเดิมทำงาน จะยังคง Query คอลัมน์เดิม (`line_uid`, `requester_name`, `car_no`, `group_car`) ได้ตามปกติ 100%
- หากต้องการรีเซ็ตเฉพาะ Tag หรือวงเงิน SmartBill ของคนใดคนหนึ่ง สามารถรัน `UPDATE users_profile SET pc_limit = 0, approve_tags = '[]' WHERE line_uid = '...';` ได้ทันที
