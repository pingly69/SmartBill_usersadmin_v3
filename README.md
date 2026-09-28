# SmartBill Users Admin (Unified D1 & Approver Management)

[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare-Workers-F38020?logo=cloudflare&logoColor=white)](https://workers.cloudflare.com/)
[![Cloudflare D1](https://img.shields.io/badge/Cloudflare-D1_SQLite-F38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/d1/)
[![LINE LIFF](https://img.shields.io/badge/LINE-LIFF_v2-00C300?logo=line&logoColor=white)](https://developers.line.biz/en/docs/liff/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.5-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)

ระบบบริหารจัดการผู้ใช้และสิทธิ์ผู้อนุมัติแบบรวมศูนย์ (Single Source of Truth) สำหรับระบบเบิกเงินสดย่อย SmartBill Petty Cash พัฒนาด้วยสถาปัตยกรรมสมัยใหม่บน **Cloudflare Workers (TypeScript) + Cloudflare D1 (SQLite) + Static Assets** เพื่อทดแทนระบบเดิมที่ใช้ Google Apps Script + Google Sheets

---

## 🌟 จุดเด่นและสถาปัตยกรรมใหม่ (Architectural Highlights)

1. **Single Source of Truth (SSOT):** รวมตาราง `users_profile` และ `approve_users` ให้เป็นตารางเดียว (`users_profile`) ขจัดปัญหาข้อมูลขัดแย้ง (Data Inconsistency) และ Race Conditions
2. **Unified Schema with Complete Attributes:** รองรับข้อมูลครบถ้วนทั้ง `pc_limit` (วงเงินสดย่อย), `display_name` (ชื่อ LINE Profile), `avatar_url`, `screen_tags` และ `approve_tags`
3. **Tag-Based Authorization (SQLite JSON1):** จัดเก็บสิทธิ์ในรูปแบบ JSON Array เช่น `["คุมวงเงินสด", "อนุมัติวงเงินสด"]` สามารถค้นหาและกรองผู้อนุมัติได้รวดเร็วผ่าน `json_each()` รองรับการขยายสิทธิ์ไปยัง Web Application อื่นๆ ในองค์กรได้ทันทีโดยไม่ต้องแก้โครงสร้างตาราง
4. **100% Dual-Interface Compatibility:** รองรับการทำงานร่วมกับ UI เดิม (`OLD_UI`) แบบ 100% โดย API Gateway จะแปลงข้อมูลระหว่าง Tag-based และ Legacy fields (`pc_limit`, `pettycash_control`, `can_approve`, `Request_Name`, `displayName`) อัตโนมัติ
5. **Local-First & Zero Extra Infrastructure:** รันและทดสอบที่เครื่อง Local ด้วย Cloudflare Wrangler Dev (`wrangler dev`) โดยใช้ฐานข้อมูล SQLite เสมือนจริงตรงกับ Production 100%

---

## 📂 โครงสร้างโปรเจกต์ (Project Structure)

```
SmartBill_usersadmin_v3/
├── public/                       # Frontend Web Application (Static Assets)
│   ├── index.html                # หน้าจอ UI (4 Screens + 3 Modals)
│   ├── css/
│   │   └── style.css             # สไตล์และการออกแบบระดับพรีเมียม
│   └── js/
│       ├── config.js             # ตั้งค่า Endpoint (/api)
│       └── app.js                # Frontend Application Logic
├── src/                          # Backend Cloudflare Worker (TypeScript)
│   ├── index.ts                  # Main Worker Entry point & Routing
│   ├── types.ts                  # Data Contracts & Schema DTOs
│   ├── utils.ts                  # Crypto PIN Generator & Helpers
│   ├── db/
│   │   ├── schema.sql            # D1 SQLite DDL (users_profile, audit_logs)
│   │   └── seed.sql              # ข้อมูลเริ่มต้นสำหรับทดสอบ
│   └── services/
│       ├── auth.service.ts       # บริการตรวจสอบ PIN และผูกบัญชี LINE
│       └── user.service.ts       # บริการ CRUD และค้นหาตาม Tag
├── wrangler.toml                 # Cloudflare Worker Configuration
├── package.json                  # Dependencies & Run Scripts
├── tsconfig.json                 # TypeScript Compiler Config
└── test_suite.js                 # Automated Integration Test Suite (18 Tests)
```

---

## 🚀 วิธีการทดสอบและรันที่ Local (Local Testing Guide)

### 1. ติดตั้ง Dependencies
```bash
npm install
```

### 2. สร้างโครงสร้างตารางใน Local D1 Database
```bash
npm run d1:init
```

### 3. นำเข้าข้อมูลตัวอย่าง (Seed Data)
```bash
npm run d1:seed
```

### 4. รัน Dev Server ที่ Local
```bash
npm run dev
```
ระบบจะเปิดบริการที่: **`http://127.0.0.1:8787`**

---

## 🔑 ข้อมูลสำหรับทดสอบ (Test Accounts & PINs)

| บทบาท (Role) | รหัส PIN | รายละเอียด / หน้าจอที่เข้าถึง |
|---|---|---|
| **Admin** | `999999` | เข้าสู่หน้าจอ **Admin Dashboard** จัดการเพิ่ม/ลบ/แก้ไขผู้ใช้ สถิติ และส่ง PIN |
| **Pending User 1** | `123456` | ทดสอบลงทะเบียน: **สมชาย ใจดี** (วงเงิน ฿5,000, ผู้ถือเงินสด = YES) |
| **Pending User 2** | `654321` | ทดสอบลงทะเบียน: **กานดา รัตนโชติ** (วงเงิน ฿15,000, ผู้อนุมัติ = YES) |
| **Active Controller** | - | **สุภาพร บุญมา** (ลงทะเบียนแล้ว, วงเงิน ฿10,000, ผู้ถือเงินสด = YES) |
| **Active Approver** | - | **มนตรี เกียรติสกุล** (ลงทะเบียนแล้ว, สิทธิ์อนุมัติเงินชดเชย = YES) |

---

## 🧪 การรัน Automated Integration Tests
สามารถทดสอบฟังก์ชัน API ครบทั้ง 18 กรณีทดสอบได้ด้วยคำสั่ง:
```bash
npm test
```

ผลการทดสอบ:
* [x] Health Check `/ping`
* [x] Static Assets Frontend Serving (`/`)
* [x] Admin Login (`verifyPin(999999)`)
* [x] User PIN Validation (`verifyPin(123456)`)
* [x] Invalid PIN Rejection
* [x] Query Approvers by Tag: `"คุมวงเงินสด"` (JSON1)
* [x] Query Approvers by Tag: `"อนุมัติวงเงินสด"` (JSON1)
* [x] Create User with Auto-generated 6-digit PIN
* [x] Unique Name Constraint Validation
* [x] LINE UID Binding & Account Activation (`registerUser`)
* [x] Update User & Tag Mapping
* [x] Delete User & Single-table ACID Transaction

---

## 📦 การย้ายข้อมูลจริงเมื่อพร้อม Go-Live (Data Migration Runbook)

อ่านคู่มือขั้นตอนการปฏิบัติการแบบละเอียดทีละขั้นตอนได้ที่:  
👉 **[old_data/DATA_MIGRATION_RUNBOOK.md](file:///c:/Antigravity_Data/SmartBill_usersadmin_v3/old_data/DATA_MIGRATION_RUNBOOK.md)**

```bash
# 1. นำไฟล์ Billing_data.xlsx ล่าสุดมาวางใน old_data/ แล้วรัน ETL รวม 2 ชีต:
npm run migrate:etl

# 2. ทดสอบนำเข้าที่ Local ก่อนเสมอ:
npm run migrate:local

# 3. นำเข้าข้อมูลขึ้นระบบจริงบน Cloudflare D1 (รองรับ UPSERT รันซ้ำได้ปลอดภัย):
npm run migrate:remote
```

---

## 🔗 คู่มือเชื่อมต่อ API สำหรับเว็บแอปอื่นๆ ในเครือ (Ecosystem Integration)

คู่มือการเรียกใช้ API สำหรับ `smartbill`, `smartbill_approve` และ `smartbill_approvePC`:  
👉 **[SMARTBILL_IAM_INTEGRATION_SPEC.md](file:///c:/Antigravity_Data/SmartBill_usersadmin_v3/SMARTBILL_IAM_INTEGRATION_SPEC.md)**

* มีตัวอย่างโค้ด JavaScript ฟังก์ชัน `fetch` ดึงรายชื่อผู้ถือเงินสด และผู้อนุมัติชดเชย
* รองรับทั้งการทดสอบที่ Local (`http://127.0.0.1:8787/api`) และบน Cloudflare Production

---

## ☁️ ขั้นตอนขึ้นระบบจริง (Production Deployment)

เมื่อพร้อมขึ้นระบบ Cloudflare Workers + D1:

1. **สร้าง Cloudflare D1 บน Cloud:**
   ```bash
   npx wrangler d1 create smartbill-prod-db
   ```
   นำ `database_id` ที่ได้ไปใส่ใน `wrangler.toml`

2. **สร้างตารางและ Seed ข้อมูลบน Cloud:**
   ```bash
   npx wrangler d1 execute smartbill-prod-db --remote --file=./src/db/schema.sql
   npx wrangler d1 execute smartbill-prod-db --remote --file=./src/db/seed.sql
   ```

3. **ตั้งค่า Admin PIN ลับ:**
   ```bash
   npx wrangler secret put ADMIN_PINCODE
   # กรอกรหัส PIN ของ Admin เช่น 999999
   ```

4. **Deploy ขึ้น Cloudflare:**
   ```bash
   npx wrangler deploy
   ```
