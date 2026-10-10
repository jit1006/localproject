/**
 * Rebuildable projection of a carton's current status/custody/holds.
 * @typedef {Object} CartonStateRecord
 * @property {string} cartonId
 * @property {string} statusCode
 * @property {"BUSINESS"|"TRANSIT"|"WAREHOUSE"|"DESTROYED"|"UNKNOWN"} custody
 * @property {string|null} vendorId
 * @property {string|null} warehouseId
 * @property {number} activeHoldCount
 * @property {string} stateSince
 * @property {number} lastEventId
 * @property {number} version
 */

export const CartonState = {
  table: "carton_state",

  /** @returns {CartonStateRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      cartonId: row.carton_id,
      statusCode: row.status_code,
      custody: row.custody,
      vendorId: row.vendor_id,
      warehouseId: row.warehouse_id,
      activeHoldCount: row.active_hold_count,
      stateSince: row.state_since,
      lastEventId: row.last_event_id,
      version: row.version,
    };
  },

  toPublic(s) {
    return {
      cartonId: s.cartonId,
      status: s.statusCode,
      custody: s.custody,
      vendorId: s.vendorId,
      warehouseId: s.warehouseId,
      activeHoldCount: s.activeHoldCount,
      stateSince: s.stateSince,
      version: s.version,
    };
  },
};
