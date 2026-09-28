export interface Env {
  DB: D1Database;
  STORAGE?: R2Bucket;
  ASSETS?: Fetcher;
  ADMIN_PINCODE: string;
  CORS_ALLOW_ORIGIN?: string;
  PIN_MIN?: string | number;
  PIN_MAX?: string | number;
  PIN_LENGTH?: string | number;
}

/**
 * Unified Database Row in D1 SQLite
 * Reference: skills/MIGRATION_CLOUDFLARE_D1_R2_SPEC.md & skills/new_users_profile_and_approve.txt
 */
export interface UserProfileRow {
  users_id: string;
  password: string;
  requester_name: string;
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
  requester_name: string;          // Aligned with Cloud D1 (IMG_DB)
  request_name: string;            // Lowercase alias
  Request_Name: string;            // Legacy uppercase alias
  users_name: string;              // Project internal alias
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
