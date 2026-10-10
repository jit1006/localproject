import { db } from "../db/connection.js";
import { ReconciliationRun, ExceptionCase } from "../models/index.js";

export function findRun(runKind, scopeKey, fingerprint) {
  const row = db
    .prepare(
      "SELECT * FROM reconciliation_run WHERE run_kind = ? AND scope_key = ? AND input_fingerprint = ?",
    )
    .get(runKind, scopeKey, fingerprint);
  return ReconciliationRun.fromRow(row);
}

export function insertRun(r) {
  const info = db
    .prepare(
      `INSERT INTO reconciliation_run (run_kind, scope_key, input_fingerprint, parameters, rule_snapshot,
          engine_version, requested_by, status, finished_at, counts)
       VALUES (@runKind, @scopeKey, @fingerprint, @parameters, @ruleSnapshot, @engineVersion, @requestedBy,
          @status, @finishedAt, @counts)`,
    )
    .run({
      runKind: r.runKind,
      scopeKey: r.scopeKey,
      fingerprint: r.inputFingerprint,
      parameters: JSON.stringify(r.parameters ?? {}),
      ruleSnapshot: JSON.stringify(r.ruleSnapshot ?? {}),
      engineVersion: r.engineVersion,
      requestedBy: r.requestedBy,
      status: r.status ?? "COMPLETED",
      finishedAt: r.finishedAt ?? null,
      counts: JSON.stringify(r.counts ?? {}),
    });
  return Number(info.lastInsertRowid);
}

export function listRuns() {
  return db
    .prepare("SELECT * FROM reconciliation_run ORDER BY started_at DESC")
    .all()
    .map(ReconciliationRun.fromRow);
}

export function listExceptions({ role, vendorId }) {
  let sql = "SELECT * FROM exception_case";
  const params = [];
  if (role === "VENDOR") {
    sql += " WHERE owner_vendor_id = ?";
    params.push(vendorId);
  } else if (role === "BUSINESS") {
    sql += " WHERE visibility = 'BUSINESS_SCOPED'";
  }
  sql += " ORDER BY last_detected_at DESC";
  return db.prepare(sql).all(...params).map(ExceptionCase.fromRow);
}
