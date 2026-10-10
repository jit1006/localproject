// Model definitions for the PRMS SQLite database.
//
// Node + SQLite has no ORM, so a "model" here is: (1) a JSDoc typedef describing
// the row shape, (2) the table/column metadata, and (3) mapper functions that
// convert between DB rows (snake_case, TEXT booleans/dates) and domain objects
// (camelCase, real booleans). Repositories use these mappers; services and
// routes work with the domain objects.

/** @typedef {"BUSINESS"|"VENDOR"|"COMPLIANCE"|"FACILITIES"} Role */

export { AppUser } from "./app_user.js";
export { Carton } from "./carton.js";
export { FileRecord } from "./file_record.js";
export { ServiceRequest } from "./service_request.js";
export { EventLogEntry } from "./event_log.js";
export { CartonState } from "./carton_state.js";
export { LegalHold } from "./legal_hold.js";
export { ReconciliationRun, ExceptionCase } from "./reconciliation.js";

/** Shared helpers used by model mappers. */
export const toBool = (v) => v === 1 || v === "1" || v === true;
export const fromBool = (v) => (v ? 1 : 0);
export const nowIso = () => new Date().toISOString();
