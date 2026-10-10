import { db } from "../db/connection.js";
import { EventLogEntry, CartonState } from "../models/index.js";

export function findByIdempotencyKey(key) {
  const row = db.prepare("SELECT * FROM event_log WHERE idempotency_key = ?").get(key);
  return EventLogEntry.fromRow(row);
}

export function maxStreamVersion(streamId) {
  const row = db.prepare("SELECT max(stream_version) AS v FROM event_log WHERE stream_id = ?").get(streamId);
  return row?.v ?? 0;
}

export function insertEvent(e) {
  const info = db
    .prepare(
      `INSERT INTO event_log (stream_kind, stream_id, stream_version, carton_id, request_id,
          event_type, occurred_at, actor_user_id, actor_role, channel, resulting_status, payload, idempotency_key)
       VALUES (@streamKind, @streamId, @streamVersion, @cartonId, @requestId, @eventType, @occurredAt,
          @actorUserId, @actorRole, @channel, @resultingStatus, @payload, @idempotencyKey)`,
    )
    .run({
      streamKind: e.streamKind,
      streamId: e.streamId,
      streamVersion: e.streamVersion,
      cartonId: e.cartonId ?? null,
      requestId: e.requestId ?? null,
      eventType: e.eventType,
      occurredAt: e.occurredAt,
      actorUserId: e.actorUserId ?? null,
      actorRole: e.actorRole,
      channel: e.channel,
      resultingStatus: e.resultingStatus ?? null,
      payload: JSON.stringify(e.payload ?? {}),
      idempotencyKey: e.idempotencyKey,
    });
  return Number(info.lastInsertRowid);
}

export function history(cartonId) {
  const rows = db
    .prepare("SELECT * FROM event_log WHERE carton_id = ? ORDER BY occurred_at ASC, event_id ASC")
    .all(cartonId);
  return rows.map((r) => EventLogEntry.toHistory(EventLogEntry.fromRow(r)));
}

// --- carton_state projection ---
export function getState(cartonId) {
  const row = db.prepare("SELECT * FROM carton_state WHERE carton_id = ?").get(cartonId);
  return CartonState.fromRow(row);
}

export function insertState(s) {
  db.prepare(
    `INSERT INTO carton_state (carton_id, status_code, custody, vendor_id, warehouse_id,
        active_hold_count, state_since, last_event_id, version)
     VALUES (@cartonId, @statusCode, @custody, @vendorId, @warehouseId, @activeHoldCount, @stateSince, @lastEventId, @version)`,
  ).run({
    cartonId: s.cartonId,
    statusCode: s.statusCode,
    custody: s.custody,
    vendorId: s.vendorId ?? null,
    warehouseId: s.warehouseId ?? null,
    activeHoldCount: s.activeHoldCount ?? 0,
    stateSince: s.stateSince,
    lastEventId: s.lastEventId,
    version: s.version,
  });
}

export function updateState(cartonId, fields) {
  const sets = [];
  const params = { cartonId };
  for (const [k, v] of Object.entries(fields)) {
    sets.push(`${k} = @${k}`);
    params[k] = v;
  }
  db.prepare(`UPDATE carton_state SET ${sets.join(", ")} WHERE carton_id = @cartonId`).run(params);
}

// --- custody intervals ---
export function openInterval(cartonId) {
  return db.prepare("SELECT * FROM custody_interval WHERE carton_id = ? AND valid_to IS NULL").get(cartonId);
}

export function closeInterval(intervalId, validTo, endEventId) {
  db.prepare("UPDATE custody_interval SET valid_to = ?, end_event_id = ? WHERE interval_id = ?").run(
    validTo,
    endEventId,
    intervalId,
  );
}

export function insertInterval(iv) {
  db.prepare(
    `INSERT INTO custody_interval (carton_id, custody, vendor_id, warehouse_id, valid_from, start_event_id)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(iv.cartonId, iv.custody, iv.vendorId ?? null, iv.warehouseId ?? null, iv.validFrom, iv.startEventId);
}
