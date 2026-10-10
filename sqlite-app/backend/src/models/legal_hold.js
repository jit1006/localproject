/**
 * @typedef {Object} LegalHoldRecord
 * @property {string} holdId
 * @property {string} cartonId
 * @property {string} matterReference
 * @property {string} reason
 * @property {string|null} raisedBy
 * @property {string} startsAt
 * @property {number} appliedEventId
 * @property {string|null} releasedAt
 * @property {string|null} releasedBy
 * @property {string|null} releaseReason
 */

export const LegalHold = {
  table: "legal_hold",

  /** @returns {LegalHoldRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      holdId: row.hold_id,
      cartonId: row.carton_id,
      matterReference: row.matter_reference,
      reason: row.reason,
      raisedBy: row.raised_by,
      startsAt: row.starts_at,
      appliedEventId: row.applied_event_id,
      releasedAt: row.released_at,
      releasedBy: row.released_by,
      releaseReason: row.release_reason,
    };
  },

  toPublic(h) {
    return {
      hold_id: h.holdId,
      carton_id: h.cartonId,
      matter_reference: h.matterReference,
      reason: h.reason,
      starts_at: h.startsAt,
      released_at: h.releasedAt,
    };
  },
};
