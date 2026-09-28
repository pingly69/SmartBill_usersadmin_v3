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
      const isPending = !isActive || !rawUid || Utils.isPendingPin(rawUid);
      
      const screenTags = Utils.safeParseJsonArray(user.screen_tags);
      const approveTags = Utils.safeParseJsonArray(user.approve_tags);

      const hasControl = approveTags.includes('คุมวงเงินสด');
      const hasApprove = approveTags.includes('อนุมัติวงเงินสด');

      const reqName = user.requester_name || '';

      return {
        users_id: user.users_id,
        requester_name: reqName,
        request_name: reqName,
        Request_Name: reqName,
        users_name: reqName,
        emp_no: user.emp_no || '',
        email: user.email || '',
        pc_limit: Number(user.pc_limit) || 0,
        // For frontend compatibility: if registered show line_uid, if pending show temporary PIN or empty
        line_uid: rawUid || (isPending && Utils.isPendingPin(rawPwd) ? rawPwd : ''),
        display_name: user.display_name || '',
        displayName: user.display_name || reqName,
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
    const reqName = Utils.sanitizeString(
      payload.requester_name || payload.request_name || payload.Request_Name || payload.users_name
    );
    const empNo = Utils.sanitizeString(payload.emp_no);
    const email = Utils.sanitizeString(payload.email);
    const pcLimit = Number(payload.pc_limit || payload['pc.limit'] || 0);

    if (!reqName) {
      return { success: false, message: 'กรุณาระบุชื่อผู้ใช้ (Request Name)' };
    }

    // 1. Check uniqueness of requester_name
    const existing = await db
      .prepare("SELECT users_id FROM users_profile WHERE requester_name = ? COLLATE NOCASE")
      .bind(reqName)
      .first();

    if (existing) {
      return { success: false, message: 'ชื่อนี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น' };
    }

    // 2. Build Screen & Approve Tags
    let screenTags: string[] = [];
    if (Array.isArray(payload.screen_tags) && payload.screen_tags.length > 0) {
      screenTags = payload.screen_tags.map(String);
    } else {
      screenTags = ["PC01"];
    }

    let approveTags: string[] = [];
    if (Array.isArray(payload.approve_tags) && payload.approve_tags.length > 0) {
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

    // 4. Single-table insert with Audit Log via batch
    await db.batch([
      db.prepare(`
        INSERT INTO users_profile (
          users_id, password, requester_name, line_uid, display_name, emp_no, email, pc_limit, avatar_url, active, screen_tags, approve_tags
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
      `).bind(userId, JSON.stringify({ pin: newPin, requester_name: reqName, empNo, pcLimit, screenTags, approveTags }))
    ]);

    return {
      success: true,
      message: 'เพิ่มผู้ใช้ใหม่สำเร็จ',
      data: {
        pin: newPin,
        users_id: userId,
        requester_name: reqName,
        request_name: reqName,
        Request_Name: reqName,
        users_name: reqName,
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
    const newName = Utils.sanitizeString(
      payload.requester_name || payload.request_name || payload.Request_Name || payload.users_name
    );
    const empNo = Utils.sanitizeString(payload.emp_no);
    const email = Utils.sanitizeString(payload.email);
    const pcLimit = payload.pc_limit !== undefined ? Number(payload.pc_limit) : undefined;

    if (!targetId && !targetUid) {
      return { success: false, message: 'ไม่พบรหัสผู้ใช้ที่ต้องการแก้ไข' };
    }
    if (!newName) {
      return { success: false, message: 'กรุณาระบุชื่อผู้ใช้ (Request Name)' };
    }

    // Locate current user safely
    let userRow: UserProfileRow | null = null;
    if (targetId) {
      userRow = await db
        .prepare("SELECT * FROM users_profile WHERE users_id = ?")
        .bind(targetId)
        .first<UserProfileRow>();
    }

    if (!userRow && targetUid) {
      userRow = await db
        .prepare(`
          SELECT * FROM users_profile 
          WHERE (line_uid != '' AND line_uid = ?1) OR (length(?1) = 6 AND password = ?1)
        `)
        .bind(targetUid)
        .first<UserProfileRow>();
    }

    if (!userRow) {
      return { success: false, message: 'ไม่พบข้อมูลผู้ใช้ในระบบ' };
    }

    // Check unique name if changed
    if (Utils.normalizeName(newName) !== Utils.normalizeName(userRow.requester_name)) {
      const duplicate = await db
        .prepare("SELECT users_id FROM users_profile WHERE requester_name = ?1 COLLATE NOCASE AND users_id != ?2")
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

    // Process Screen Tags
    let screenTags: string[];
    if (Array.isArray(payload.screen_tags)) {
      screenTags = payload.screen_tags.map(String);
    } else {
      screenTags = Utils.safeParseJsonArray(userRow.screen_tags);
    }

    // Process Approve Tags
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
        SET requester_name = ?1,
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
      `).bind(userRow.users_id, JSON.stringify({ requester_name: newName, empNo, email, pcLimit: finalPcLimit, regeneratedPin: !!generatedPin }))
    ]);

    return {
      success: true,
      message: 'บันทึกการแก้ไขข้อมูลสำเร็จ',
      data: generatedPin ? { pin: generatedPin, requester_name: newName, request_name: newName, Request_Name: newName, users_name: newName } : null
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
      .prepare("SELECT * FROM users_profile WHERE users_id = ?1 OR (line_uid != '' AND line_uid = ?1) OR (length(?1) = 6 AND password = ?1)")
      .bind(target)
      .first<UserProfileRow>();

    if (!userRow) {
      return { success: false, message: 'ไม่พบข้อมูลผู้ใช้ในระบบ' };
    }

    await db.batch([
      db.prepare("DELETE FROM users_profile WHERE users_id = ?").bind(userRow.users_id),
      db.prepare("INSERT INTO audit_logs (action, performed_by, target_identifier) VALUES ('DELETE_USER', 'ADMIN', ?)")
        .bind(userRow.requester_name)
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
      SELECT u.users_id, u.requester_name, u.emp_no, u.pc_limit, u.line_uid, u.display_name, u.email, u.screen_tags, u.approve_tags
      FROM users_profile u, json_each(u.approve_tags) j
      WHERE u.active = 'Y' AND j.value = ?
    `).bind(cleanTag).all<UserProfileRow>();

    const users = (res.results || []).map(u => ({
      users_id: u.users_id,
      requester_name: u.requester_name,
      request_name: u.requester_name,
      Request_Name: u.requester_name,
      users_name: u.requester_name,
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
