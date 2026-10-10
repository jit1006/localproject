import { db } from "../db/connection.js";
import { Carton, FileRecord } from "../models/index.js";

export function findById(cartonId) {
  const row = db.prepare("SELECT * FROM carton WHERE carton_id = ?").get(cartonId);
  return Carton.fromRow(row);
}

export function insert(c) {
  db.prepare(
    `INSERT INTO carton (carton_id, entity_id, department_id, owner_user_id, document_type,
        archival_policy, carton_created_date, retention_trigger_date, declared_file_count,
        assigned_vendor_id, barcode, remarks)
     VALUES (@cartonId, @entityId, @departmentId, @ownerUserId, @documentType, @archivalPolicy,
        @cartonCreatedDate, @retentionTriggerDate, @declaredFileCount, @assignedVendorId, @barcode, @remarks)`,
  ).run({
    cartonId: c.cartonId,
    entityId: c.entityId,
    departmentId: c.departmentId,
    ownerUserId: c.ownerUserId,
    documentType: c.documentType,
    archivalPolicy: c.archivalPolicy,
    cartonCreatedDate: c.cartonCreatedDate,
    retentionTriggerDate: c.retentionTriggerDate ?? null,
    declaredFileCount: c.declaredFileCount ?? null,
    assignedVendorId: c.assignedVendorId,
    barcode: c.barcode ?? null,
    remarks: c.remarks ?? null,
  });
  return findById(c.cartonId);
}

export function insertFile(f) {
  db.prepare(
    `INSERT INTO file_record (file_id, carton_id, file_ref, document_type, file_description, document_year, contains_pii)
     VALUES (@fileId, @cartonId, @fileRef, @documentType, @fileDescription, @documentYear, @containsPii)`,
  ).run({
    fileId: f.fileId,
    cartonId: f.cartonId,
    fileRef: f.fileRef,
    documentType: f.documentType,
    fileDescription: f.fileDescription ?? null,
    documentYear: f.documentYear ?? null,
    containsPii: f.containsPii ? 1 : 0,
  });
}

export function listFiles(cartonId) {
  const rows = db.prepare("SELECT * FROM file_record WHERE carton_id = ? ORDER BY file_id").all(cartonId);
  return rows.map(FileRecord.fromRow);
}

export function fileExists(fileId) {
  return !!db.prepare("SELECT 1 FROM file_record WHERE file_id = ?").get(fileId);
}

export function retention(cartonId) {
  return db
    .prepare(
      `SELECT carton_id, retention_trigger_date, policy_id, policy_revision, retention_years,
              destruction_due_on, calculation_status
       FROM carton_retention WHERE carton_id = ?`,
    )
    .get(cartonId) ?? null;
}

/** Dashboard aggregation scoped by role. */
export function countsByStatus({ role, entityId, departmentId, vendorId }) {
  return db
    .prepare(
      `SELECT cs.status_code, count(*) AS n
       FROM carton_state cs JOIN carton c ON c.carton_id = cs.carton_id
       WHERE (@role <> 'BUSINESS' OR (c.entity_id = @entityId AND c.department_id = @departmentId))
         AND (@role <> 'VENDOR'   OR c.assigned_vendor_id = @vendorId)
       GROUP BY cs.status_code ORDER BY n DESC`,
    )
    .all({ role, entityId: entityId ?? null, departmentId: departmentId ?? null, vendorId: vendorId ?? null });
}

export function totalCartons({ role, entityId, departmentId, vendorId }) {
  const row = db
    .prepare(
      `SELECT count(*) AS n FROM carton c
       WHERE (@role <> 'BUSINESS' OR (c.entity_id = @entityId AND c.department_id = @departmentId))
         AND (@role <> 'VENDOR'   OR c.assigned_vendor_id = @vendorId)`,
    )
    .get({ role, entityId: entityId ?? null, departmentId: departmentId ?? null, vendorId: vendorId ?? null });
  return row.n;
}
