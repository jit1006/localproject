/**
 * @typedef {Object} CartonRecord
 * @property {string} cartonId
 * @property {string} entityId
 * @property {string} departmentId
 * @property {string} ownerUserId
 * @property {string} documentType
 * @property {string} archivalPolicy
 * @property {string} cartonCreatedDate   ISO date (YYYY-MM-DD)
 * @property {string|null} retentionTriggerDate
 * @property {number|null} declaredFileCount
 * @property {string} assignedVendorId
 * @property {string|null} barcode
 * @property {string|null} remarks
 */

export const Carton = {
  table: "carton",

  /** @returns {CartonRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      cartonId: row.carton_id,
      entityId: row.entity_id,
      departmentId: row.department_id,
      ownerUserId: row.owner_user_id,
      documentType: row.document_type,
      archivalPolicy: row.archival_policy,
      cartonCreatedDate: row.carton_created_date,
      retentionTriggerDate: row.retention_trigger_date,
      declaredFileCount: row.declared_file_count,
      assignedVendorId: row.assigned_vendor_id,
      barcode: row.barcode,
      remarks: row.remarks,
    };
  },

  toPublic(c) {
    return {
      carton_id: c.cartonId,
      entity_id: c.entityId,
      department_id: c.departmentId,
      document_type: c.documentType,
      archival_policy: c.archivalPolicy,
      assigned_vendor_id: c.assignedVendorId,
      retention_trigger_date: c.retentionTriggerDate,
      declared_file_count: c.declaredFileCount,
      barcode: c.barcode,
    };
  },
};
