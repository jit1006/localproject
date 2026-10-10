import { db } from "../db/connection.js";
import { AppUser } from "../models/index.js";

export function findByEmail(email) {
  const row = db.prepare("SELECT * FROM app_user WHERE lower(email) = lower(?)").get(email);
  return AppUser.fromRow(row);
}

export function findById(userId) {
  const row = db.prepare("SELECT * FROM app_user WHERE user_id = ?").get(userId);
  return AppUser.fromRow(row);
}

export function upsert(user) {
  const r = AppUser.toRow(user);
  db.prepare(
    `INSERT INTO app_user (user_id, full_name, email, role_code, entity_id, department_id, vendor_id, password_hash, is_active)
     VALUES (@user_id, @full_name, @email, @role_code, @entity_id, @department_id, @vendor_id, @password_hash, @is_active)
     ON CONFLICT(user_id) DO UPDATE SET
       full_name=@full_name, email=@email, role_code=@role_code, entity_id=@entity_id,
       department_id=@department_id, vendor_id=@vendor_id, password_hash=@password_hash, is_active=@is_active`,
  ).run(r);
  return findById(user.userId);
}

// --- sessions ---
export function createSession(tokenHash, userId, expiresAt) {
  db.prepare(
    "INSERT INTO user_session (token_hash, user_id, expires_at) VALUES (?, ?, ?)",
  ).run(tokenHash, userId, expiresAt);
}

export function findSession(tokenHash) {
  return db.prepare("SELECT * FROM user_session WHERE token_hash = ?").get(tokenHash);
}

export function revokeSession(tokenHash, revokedAt) {
  db.prepare("UPDATE user_session SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL").run(
    revokedAt,
    tokenHash,
  );
}
