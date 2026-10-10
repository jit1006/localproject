import { toBool, fromBool } from "./index.js";

/**
 * @typedef {Object} AppUserRecord
 * @property {string} userId
 * @property {string} fullName
 * @property {string} email
 * @property {"BUSINESS"|"VENDOR"|"COMPLIANCE"|"FACILITIES"} roleCode
 * @property {string|null} entityId
 * @property {string|null} departmentId
 * @property {string|null} vendorId
 * @property {string|null} passwordHash
 * @property {boolean} isActive
 * @property {string} createdAt
 */

export const AppUser = {
  table: "app_user",
  columns: [
    "user_id", "full_name", "email", "role_code", "entity_id",
    "department_id", "vendor_id", "password_hash", "is_active", "created_at",
  ],

  /** @returns {AppUserRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      userId: row.user_id,
      fullName: row.full_name,
      email: row.email,
      roleCode: row.role_code,
      entityId: row.entity_id,
      departmentId: row.department_id,
      vendorId: row.vendor_id,
      passwordHash: row.password_hash,
      isActive: toBool(row.is_active),
      createdAt: row.created_at,
    };
  },

  /** Domain object -> DB row (for inserts/updates). */
  toRow(u) {
    return {
      user_id: u.userId,
      full_name: u.fullName,
      email: u.email,
      role_code: u.roleCode,
      entity_id: u.entityId ?? null,
      department_id: u.departmentId ?? null,
      vendor_id: u.vendorId ?? null,
      password_hash: u.passwordHash ?? null,
      is_active: fromBool(u.isActive ?? true),
    };
  },

  /** Public projection: never leak the password hash. */
  toPublic(u) {
    return {
      user_id: u.userId,
      full_name: u.fullName,
      email: u.email,
      role_code: u.roleCode,
      entity_id: u.entityId,
      department_id: u.departmentId,
      vendor_id: u.vendorId,
    };
  },
};
