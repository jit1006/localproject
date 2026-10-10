import { conflict, forbidden, notFound, unprocessable } from "../errors.js";
import { tx } from "../db/connection.js";
import { requestRepo, holdRepo, eventRepo } from "../repositories/index.js";
import { appendCartonEvent } from "./event_engine.js";
import * as scope from "./scope.js";
import { nowIso } from "../models/index.js";

const REQUEST_EVENT = {
  PICKUP: "PICKUP_REQUESTED",
  RETRIEVAL: "RETRIEVAL_REQUESTED",
  RETURN: "RETURN_REQUESTED",
  DESTRUCTION: "DESTRUCTION_REQUESTED",
};

export function raiseRequest(user, carton, { requestId, requestType }) {
  scope.assertCanRaiseForCarton(user, carton);
  if (!REQUEST_EVENT[requestType]) throw unprocessable(`Unknown request_type '${requestType}'`);
  if (requestType === "DESTRUCTION" && holdRepo.activeForCarton(carton.cartonId)) {
    throw conflict("Carton is under an active legal hold; destruction is blocked");
  }

  const now = nowIso();
  return tx(() => {
    const req = requestRepo.insert({
      requestId,
      cartonId: carton.cartonId,
      requestType,
      vendorId: carton.assignedVendorId,
      raisedBy: user.userId,
      raisedAt: now,
      requestStatus: "Open",
    });
    appendCartonEvent({
      cartonId: carton.cartonId,
      eventType: REQUEST_EVENT[requestType],
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `request:${requestId}`,
      requestId,
      payload: { requestType },
    });
    return req;
  });
}

function loadRequest(requestId) {
  const req = requestRepo.findById(requestId);
  if (!req) throw notFound(`Request ${requestId} not found`);
  return req;
}

export function vendorAction(user, { requestId, eventType, markCompleted }) {
  const req = loadRequest(requestId);
  scope.assertCanActOnRequest(user, req);
  const now = nowIso();
  return tx(() => {
    appendCartonEvent({
      cartonId: req.cartonId,
      eventType,
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `${eventType}:${requestId}`,
      requestId,
    });
    const fields = { request_status: markCompleted ? "Completed" : "In Progress" };
    if (!req.vendorAckAt) fields.vendor_ack_at = now;
    if (markCompleted) fields.completed_at = now;
    return requestRepo.setStatus(requestId, fields);
  });
}

export function approveDestruction(user, requestId) {
  if (user.roleCode !== "COMPLIANCE") throw forbidden("Only Compliance can approve destruction");
  const req = loadRequest(requestId);
  if (req.requestType !== "DESTRUCTION") throw unprocessable("Only destruction requests can be approved");
  if (req.approvedBy) throw conflict("Request already approved");
  if (req.raisedBy === user.userId) throw forbidden("Approver must differ from the requester (separation of duties)");
  if (holdRepo.activeForCarton(req.cartonId)) throw conflict("Carton is under an active legal hold");

  const now = nowIso();
  return tx(() => {
    appendCartonEvent({
      cartonId: req.cartonId,
      eventType: "DESTRUCTION_APPROVED",
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `approve:${requestId}`,
      requestId,
    });
    return requestRepo.setStatus(requestId, {
      approved_by: user.userId,
      approved_at: now,
      request_status: "In Progress",
    });
  });
}

export function executeDestruction(user, requestId) {
  const req = loadRequest(requestId);
  scope.assertCanActOnRequest(user, req);
  if (!req.approvedBy) throw conflict("Destruction has not been approved");
  // Re-check at execution: a hold applied AFTER approval still blocks.
  if (holdRepo.activeForCarton(req.cartonId)) {
    throw conflict("Carton is under an active legal hold; destruction blocked at execution");
  }
  const state = eventRepo.getState(req.cartonId);
  if (state && state.custody !== "WAREHOUSE") throw conflict("Carton must be in warehouse custody to be destroyed");

  const now = nowIso();
  return tx(() => {
    appendCartonEvent({
      cartonId: req.cartonId,
      eventType: "DESTROYED",
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `destroy:${requestId}`,
      requestId,
    });
    return requestRepo.setStatus(requestId, { request_status: "Completed", completed_at: now });
  });
}

export const listVendorQueue = (vendorId) => requestRepo.listForVendor(vendorId);
