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

    // Fetch existing pending PINs from users_profile
    try {
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
    } catch (err) {
      console.warn('Note: Could not query existing PINs, proceeding with crypto random fallback', err);
    }

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
