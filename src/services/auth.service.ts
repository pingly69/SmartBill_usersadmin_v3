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

    const adminPin = String(this.env.ADMIN_PINCODE || '999999').trim();

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

        const reqName = userRow.requester_name || '';
        return {
          success: true,
          role: 'USER',
          isPending: true,
          data: {
            usersId: userRow.users_id,
            requesterName: reqName,
            requestName: reqName,
            usersName: reqName,
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
            password = '',
            active = 'Y',
            updated_at = datetime('now')
        WHERE users_id = ?4
      `).bind(uid, name, pic, userRow.users_id),

      db.prepare(`
        INSERT INTO audit_logs (action, performed_by, target_identifier, details_json)
        VALUES ('REGISTER_USER', ?1, ?2, ?3)
      `).bind(uid, userRow.requester_name, JSON.stringify({ displayName: name, avatarUrl: pic, previousPin: pin }))
    ]);

    return {
      success: true,
      message: 'ยืนยันตัวตนสำเร็จ',
      data: {
        lineUid: uid,
        displayName: name,
        requesterName: userRow.requester_name,
        requestName: userRow.requester_name,
        usersName: userRow.requester_name
      }
    };
  }
}
