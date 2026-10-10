import { db } from "../db/connection.js";
import { ServiceRequest } from "../models/index.js";

export function findById(requestId) {
  const row = db.prepare("SELECT * FROM service_request WHERE request_id = ?").get(requestId);
  return ServiceRequest.fromRow(row);
}

export function insert(r) {
  db.prepare(
    `INSERT INTO service_request (request_id, carton_id, request_type, vendor_id, raised_by, raised_at, request_status)
     VALUES (@requestId, @cartonId, @requestType, @vendorId, @raisedBy, @raisedAt, @requestStatus)`,
  ).run({
    requestId: r.requestId,
    cartonId: r.cartonId,
    requestType: r.requestType,
    vendorId: r.vendorId,
    raisedBy: r.raisedBy,
    raisedAt: r.raisedAt,
    requestStatus: r.requestStatus,
  });
  return findById(r.requestId);
}

export function setStatus(requestId, fields) {
  const sets = [];
  const params = { requestId };
  for (const [k, v] of Object.entries(fields)) {
    sets.push(`${k} = @${k}`);
    params[k] = v;
  }
  db.prepare(`UPDATE service_request SET ${sets.join(", ")} WHERE request_id = @requestId`).run(params);
  return findById(requestId);
}

export function listForVendor(vendorId) {
  const rows = db
    .prepare("SELECT * FROM service_request WHERE vendor_id = ? ORDER BY raised_at DESC")
    .all(vendorId);
  return rows.map(ServiceRequest.fromRow);
}
