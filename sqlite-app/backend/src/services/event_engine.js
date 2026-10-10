// Event engine: append a canonical carton event and update projections.
// Must be called inside a tx() by the command service so append + projection
// update are atomic. Idempotent by idempotency key.
import { conflict, unprocessable } from "../errors.js";
import { db } from "../db/connection.js";
import { eventRepo } from "../repositories/index.js";
import { nowIso } from "../models/index.js";

// Custody derived from the resulting carton status.
const STATUS_CUSTODY = {
  Created: "BUSINESS",
  "Pickup Requested": "BUSINESS",
  "In Transit to Vendor": "TRANSIT",
  "In Storage": "WAREHOUSE",
  "Retrieval Requested": "WAREHOUSE",
  "With Business": "BUSINESS",
  "Return Requested": "BUSINESS",
  "Destruction Requested": "WAREHOUSE",
  "Approved for Destruction": "WAREHOUSE",
  Destroyed: "DESTROYED",
  Missing: "UNKNOWN",
};

function eventTypeDef(eventType) {
  return db.prepare("SELECT * FROM event_type WHERE event_type = ?").get(eventType);
}

function transition(fromStatus, eventType) {
  return db
    .prepare("SELECT to_status FROM lifecycle_transition WHERE from_status = ? AND event_type = ?")
    .get(fromStatus, eventType);
}

/**
 * Append one carton event + update projections. Idempotent.
 * @returns {{eventId:number, resultingStatus:string|null, deduplicated:boolean}}
 */
export function appendCartonEvent({
  cartonId,
  eventType,
  actorUserId,
  actorRole,
  channel = "API",
  occurredAt = null,
  idempotencyKey,
  requestId = null,
  payload = {},
}) {
  // Idempotency: a prior append with the same key returns the original.
  const existing = eventRepo.findByIdempotencyKey(idempotencyKey);
  if (existing) {
    return { eventId: existing.eventId, resultingStatus: existing.resultingStatus, deduplicated: true };
  }

  const et = eventTypeDef(eventType);
  if (!et) throw unprocessable(`Unknown event_type '${eventType}'`);

  const state = eventRepo.getState(cartonId);
  const currentStatus = state?.statusCode ?? null;

  let resultingStatus = et.resulting_status; // may be null (non-state-changing)
  if (resultingStatus != null && currentStatus != null) {
    if (currentStatus === "Destroyed") throw conflict("Carton is in a terminal state and cannot change");
    const t = transition(currentStatus, eventType);
    if (!t) throw conflict(`Illegal transition: ${eventType} not allowed from status '${currentStatus}'`);
    resultingStatus = t.to_status;
  }

  const occurred = occurredAt ?? nowIso();
  const version = eventRepo.maxStreamVersion(cartonId) + 1;

  const eventId = eventRepo.insertEvent({
    streamKind: "CARTON",
    streamId: cartonId,
    streamVersion: version,
    cartonId,
    requestId,
    eventType,
    occurredAt: occurred,
    actorUserId,
    actorRole,
    channel,
    resultingStatus,
    payload,
    idempotencyKey,
  });

  if (resultingStatus != null) applyStatus(cartonId, resultingStatus, eventId, occurred);

  return { eventId, resultingStatus, deduplicated: false };
}

// When custody is WAREHOUSE the schema requires vendor_id + warehouse_id. We use
// the carton's assigned vendor and that vendor's first warehouse as the receiving
// location. (A production flow would take the exact warehouse from the vendor's
// receipt input; this keeps the projection invariant satisfied deterministically.)
function warehouseFor(cartonId) {
  const carton = db.prepare("SELECT assigned_vendor_id FROM carton WHERE carton_id = ?").get(cartonId);
  if (!carton) return { vendorId: null, warehouseId: null };
  const wh = db
    .prepare("SELECT location_id FROM warehouse WHERE vendor_id = ? ORDER BY location_id LIMIT 1")
    .get(carton.assigned_vendor_id);
  return { vendorId: carton.assigned_vendor_id, warehouseId: wh?.location_id ?? null };
}

function applyStatus(cartonId, status, eventId, occurred) {
  const custody = STATUS_CUSTODY[status] ?? "UNKNOWN";
  const loc = custody === "WAREHOUSE" ? warehouseFor(cartonId) : { vendorId: null, warehouseId: null };
  const state = eventRepo.getState(cartonId);

  if (!state) {
    eventRepo.insertState({
      cartonId,
      statusCode: status,
      custody,
      vendorId: loc.vendorId,
      warehouseId: loc.warehouseId,
      stateSince: occurred,
      lastEventId: eventId,
      version: 1,
    });
  } else {
    const fields = {
      status_code: status,
      last_event_id: eventId,
      version: state.version + 1,
      vendor_id: loc.vendorId,
      warehouse_id: loc.warehouseId,
    };
    if (state.custody !== custody) {
      const open = eventRepo.openInterval(cartonId);
      if (open) eventRepo.closeInterval(open.interval_id, occurred, eventId);
      fields.custody = custody;
      fields.state_since = occurred;
    }
    eventRepo.updateState(cartonId, fields);
  }

  // Ensure one open custody interval (except terminal).
  const open = eventRepo.openInterval(cartonId);
  if (!open && custody !== "DESTROYED") {
    eventRepo.insertInterval({
      cartonId,
      custody,
      vendorId: loc.vendorId,
      warehouseId: loc.warehouseId,
      validFrom: occurred,
      startEventId: eventId,
    });
  }
}
