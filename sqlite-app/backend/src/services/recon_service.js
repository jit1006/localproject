// Reconciliation run/exception framework. The three full detection engines
// (inventory as-of custody, invoice arithmetic + independent cost match,
// certificate vs hold/event) are the documented next increment — see docs.
import { createHash } from "node:crypto";
import { config } from "../config.js";
import { reconRepo } from "../repositories/index.js";
import { nowIso } from "../models/index.js";

export function startRun(user, { runKind, scopeKey, parameters = {} }) {
  const ruleSnapshot = { engineVersion: config.engineVersion };
  const fingerprint = createHash("sha256")
    .update(JSON.stringify({ runKind, scopeKey, parameters, ruleSnapshot }))
    .digest("hex");

  // Idempotency: same kind + scope + fingerprint returns the existing run.
  const existing = reconRepo.findRun(runKind, scopeKey, fingerprint);
  if (existing) return { run_id: existing.runId, status: existing.status, deduplicated: true };

  const runId = reconRepo.insertRun({
    runKind,
    scopeKey,
    inputFingerprint: fingerprint,
    parameters,
    ruleSnapshot,
    engineVersion: config.engineVersion,
    requestedBy: user.userId,
    status: "COMPLETED",
    finishedAt: nowIso(),
    counts: { note: "engine stub — findings produced by the engine increment" },
  });
  return { run_id: runId, status: "COMPLETED", deduplicated: false };
}

export const listRuns = () => reconRepo.listRuns();
export const listExceptions = (user) => reconRepo.listExceptions({ role: user.roleCode, vendorId: user.vendorId });
