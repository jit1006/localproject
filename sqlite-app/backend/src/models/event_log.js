/**
 * One canonical append-only event. carton_state and custody_interval are
 * rebuildable projections of this stream.
 *
 * @typedef {Object} EventLogRecord
 * @property {number} eventId
 * @property {string} streamKind
 * @property {string} streamId
 * @property {number} streamVersion
 * @property {string|null} cartonId
 * @property {string|null} requestId
 * @property {string} eventType
 * @property {string} occurredAt
 * @property {string} recordedAt
 * @property {string|null} actorUserId
 * @property {string} actorRole
 * @property {string} channel
 * @property {string|null} resultingStatus   null = status unchanged
 * @property {object} payload
 * @property {string} idempotencyKey
 */

export const EventLogEntry = {
  table: "event_log",

  /** @returns {EventLogRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      eventId: row.event_id,
      streamKind: row.stream_kind,
      streamId: row.stream_id,
      streamVersion: row.stream_version,
      cartonId: row.carton_id,
      requestId: row.request_id,
      eventType: row.event_type,
      occurredAt: row.occurred_at,
      recordedAt: row.recorded_at,
      actorUserId: row.actor_user_id,
      actorRole: row.actor_role,
      channel: row.channel,
      resultingStatus: row.resulting_status,
      payload: row.payload ? JSON.parse(row.payload) : {},
      idempotencyKey: row.idempotency_key,
    };
  },

  toHistory(e) {
    return {
      eventId: e.eventId,
      eventType: e.eventType,
      occurredAt: e.occurredAt,
      actorRole: e.actorRole,
      actorUserId: e.actorUserId,
      resultingStatus: e.resultingStatus,
      requestId: e.requestId,
      payload: e.payload,
    };
  },
};
