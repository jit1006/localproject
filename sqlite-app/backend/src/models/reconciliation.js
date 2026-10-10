/**
 * @typedef {Object} ReconciliationRunRecord
 * @property {number} runId
 * @property {string} runKind
 * @property {string} scopeKey
 * @property {string} inputFingerprint
 * @property {string} status
 * @property {string} startedAt
 */

export const ReconciliationRun = {
  table: "reconciliation_run",
  fromRow(row) {
    if (!row) return null;
    return {
      runId: row.run_id,
      runKind: row.run_kind,
      scopeKey: row.scope_key,
      inputFingerprint: row.input_fingerprint,
      status: row.status,
      startedAt: row.started_at,
    };
  },
  toPublic(r) {
    return {
      run_id: r.runId,
      run_kind: r.runKind,
      scope_key: r.scopeKey,
      status: r.status,
      started_at: r.startedAt,
    };
  },
};

/**
 * @typedef {Object} ExceptionCaseRecord
 * @property {number} exceptionId
 * @property {string} exceptionType
 * @property {string} severity
 * @property {string} ownerRole
 * @property {string|null} ownerVendorId
 * @property {string} subjectReference
 * @property {string} visibility
 * @property {string} status
 */

export const ExceptionCase = {
  table: "exception_case",
  fromRow(row) {
    if (!row) return null;
    return {
      exceptionId: row.exception_id,
      exceptionType: row.exception_type,
      severity: row.severity,
      ownerRole: row.owner_role,
      ownerVendorId: row.owner_vendor_id,
      subjectReference: row.subject_reference,
      visibility: row.visibility,
      status: row.status,
    };
  },
  toPublic(e) {
    return {
      exception_id: e.exceptionId,
      exception_type: e.exceptionType,
      severity: e.severity,
      owner_role: e.ownerRole,
      status: e.status,
      subject_reference: e.subjectReference,
    };
  },
};
