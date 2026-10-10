/**
 * @typedef {Object} ServiceRequestRecord
 * @property {string} requestId
 * @property {string} cartonId
 * @property {"PICKUP"|"RETRIEVAL"|"RETURN"|"DESTRUCTION"} requestType
 * @property {string} vendorId
 * @property {string} raisedBy
 * @property {string} raisedAt
 * @property {string} requestStatus
 * @property {string|null} approvedBy
 * @property {string|null} approvedAt
 * @property {string|null} vendorAckAt
 * @property {string|null} completedAt
 */

export const ServiceRequest = {
  table: "service_request",

  /** @returns {ServiceRequestRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      requestId: row.request_id,
      cartonId: row.carton_id,
      requestType: row.request_type,
      vendorId: row.vendor_id,
      raisedBy: row.raised_by,
      raisedAt: row.raised_at,
      requestStatus: row.request_status,
      approvedBy: row.approved_by,
      approvedAt: row.approved_at,
      vendorAckAt: row.vendor_ack_at,
      completedAt: row.completed_at,
    };
  },

  toPublic(r) {
    return {
      request_id: r.requestId,
      carton_id: r.cartonId,
      request_type: r.requestType,
      vendor_id: r.vendorId,
      request_status: r.requestStatus,
      approved_by: r.approvedBy,
    };
  },
};
