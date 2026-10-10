import { conflict, forbidden, notFound } from "../errors.js";
import { tx } from "../db/connection.js";
import { holdRepo, eventRepo } from "../repositories/index.js";
import { appendCartonEvent } from "./event_engine.js";
import { nowIso } from "../models/index.js";

export function applyHold(user, { cartonId, holdId, matterReference, reason }) {
  if (user.roleCode !== "COMPLIANCE") throw forbidden("Only Compliance can apply legal holds");
  if (holdRepo.findById(holdId)) throw conflict(`Hold ${holdId} already exists`);

  const now = nowIso();
  return tx(() => {
    const { eventId } = appendCartonEvent({
      cartonId,
      eventType: "LEGAL_HOLD_APPLIED",
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `hold-apply:${holdId}`,
      payload: { matterReference, reason },
    });
    const hold = holdRepo.insert({
      holdId,
      cartonId,
      matterReference,
      reason,
      raisedBy: user.userId,
      startsAt: now,
      appliedEventId: eventId,
    });
    const state = eventRepo.getState(cartonId);
    if (state) eventRepo.updateState(cartonId, { active_hold_count: state.activeHoldCount + 1 });
    return hold;
  });
}

export function releaseHold(user, holdId, reason) {
  if (user.roleCode !== "COMPLIANCE") throw forbidden("Only Compliance can release legal holds");
  const hold = holdRepo.findById(holdId);
  if (!hold) throw notFound(`Hold ${holdId} not found`);
  if (hold.releasedAt) throw conflict("Hold already released");

  const now = nowIso();
  return tx(() => {
    const { eventId } = appendCartonEvent({
      cartonId: hold.cartonId,
      eventType: "LEGAL_HOLD_RELEASED",
      actorUserId: user.userId,
      actorRole: user.roleCode,
      occurredAt: now,
      idempotencyKey: `hold-release:${holdId}`,
      payload: { reason },
    });
    const released = holdRepo.release(holdId, {
      releasedAt: now,
      releasedBy: user.userId,
      releaseReason: reason,
      releasedEventId: eventId,
    });
    const state = eventRepo.getState(hold.cartonId);
    if (state && state.activeHoldCount > 0) {
      eventRepo.updateState(hold.cartonId, { active_hold_count: state.activeHoldCount - 1 });
    }
    return released;
  });
}

export const listHolds = (activeOnly) => holdRepo.list(activeOnly);
