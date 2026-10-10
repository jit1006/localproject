import { db } from "../db/connection.js";
import { LegalHold } from "../models/index.js";

export function findById(holdId) {
  const row = db.prepare("SELECT * FROM legal_hold WHERE hold_id = ?").get(holdId);
  return LegalHold.fromRow(row);
}

export function activeForCarton(cartonId) {
  const row = db
    .prepare("SELECT * FROM legal_hold WHERE carton_id = ? AND released_at IS NULL LIMIT 1")
    .get(cartonId);
  return LegalHold.fromRow(row);
}

export function insert(h) {
  db.prepare(
    `INSERT INTO legal_hold (hold_id, carton_id, matter_reference, reason, raised_by, starts_at, applied_event_id)
     VALUES (@holdId, @cartonId, @matterReference, @reason, @raisedBy, @startsAt, @appliedEventId)`,
  ).run({
    holdId: h.holdId,
    cartonId: h.cartonId,
    matterReference: h.matterReference,
    reason: h.reason,
    raisedBy: h.raisedBy ?? null,
    startsAt: h.startsAt,
    appliedEventId: h.appliedEventId,
  });
  return findById(h.holdId);
}

export function release(holdId, { releasedAt, releasedBy, releaseReason, releasedEventId }) {
  db.prepare(
    `UPDATE legal_hold SET released_at = ?, release_precision = 'TIMESTAMP', released_by = ?,
       release_reason = ?, released_event_id = ? WHERE hold_id = ?`,
  ).run(releasedAt, releasedBy, releaseReason, releasedEventId, holdId);
  return findById(holdId);
}

export function list(activeOnly) {
  const sql = activeOnly
    ? "SELECT * FROM legal_hold WHERE released_at IS NULL ORDER BY starts_at DESC"
    : "SELECT * FROM legal_hold ORDER BY starts_at DESC";
  return db.prepare(sql).all().map(LegalHold.fromRow);
}
