import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type { Carton, CartonHistory } from "../api/types";
import { useAuth } from "../auth/AuthContext";

export function CartonDetailPage() {
  const { cartonId } = useParams<{ cartonId: string }>();
  const { user } = useAuth();
  const [carton, setCarton] = useState<Carton | null>(null);
  const [history, setHistory] = useState<CartonHistory | null>(null);
  const [retention, setRetention] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = () => {
    if (!cartonId) return;
    setError(null);
    api.get<Carton>(`/cartons/${cartonId}`).then(setCarton).catch((e) => setError(e.message));
    api.get<CartonHistory>(`/cartons/${cartonId}/history`).then(setHistory).catch(() => {});
    api.get<Record<string, unknown>>(`/cartons/${cartonId}/retention`).then(setRetention).catch(() => {});
  };
  useEffect(load, [cartonId]);

  const raiseRequest = async (requestType: string) => {
    if (!cartonId) return;
    setNotice(null);
    try {
      await api.post("/requests", {
        request_id: `${requestType}-${cartonId}-${Date.now()}`,
        carton_id: cartonId,
        request_type: requestType,
      });
      setNotice(`${requestType} request raised.`);
      load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Request failed");
    }
  };

  if (error) return <p className="error">{error}</p>;
  if (!carton) return <p>Loading carton…</p>;
  const canRequest = user?.role_code === "BUSINESS";

  return (
    <section>
      <h2>Carton {carton.carton_id}</h2>
      <div className="card">
        <dl className="detail">
          <dt>Entity / Dept</dt><dd>{carton.entity_id} / {carton.department_id}</dd>
          <dt>Document type</dt><dd>{carton.document_type}</dd>
          <dt>Archival policy</dt><dd>{carton.archival_policy}</dd>
          <dt>Vendor</dt><dd>{carton.assigned_vendor_id}</dd>
          {retention && (
            <>
              <dt>Destruction due</dt>
              <dd>{String(retention.destruction_due_on ?? "—")} <span className="muted">({String(retention.calculation_status)})</span></dd>
            </>
          )}
        </dl>
      </div>

      {canRequest && (
        <div className="card">
          <h3>Raise a request</h3>
          <div className="row">
            <button onClick={() => raiseRequest("PICKUP")}>Pickup</button>
            <button onClick={() => raiseRequest("RETRIEVAL")}>Retrieval</button>
            <button onClick={() => raiseRequest("RETURN")}>Return</button>
            <button onClick={() => raiseRequest("DESTRUCTION")}>Destruction</button>
          </div>
          {notice && <p className="notice">{notice}</p>}
        </div>
      )}

      <div className="card">
        <h3>Current state</h3>
        {history?.state ? (
          <dl className="detail">
            <dt>Status</dt><dd>{String(history.state.status)}</dd>
            <dt>Location</dt><dd>{String(history.state.currentLocationId ?? "—")}</dd>
            <dt>Legal hold</dt><dd>{history.state.legalHoldFlag ? "Yes" : "No"}</dd>
          </dl>
        ) : (
          <p className="empty">No state yet.</p>
        )}
      </div>

      <div className="card">
        <h3>History (event log)</h3>
        <table className="data-table">
          <thead><tr><th>When</th><th>Event</th><th>Actor</th><th>Resulting status</th></tr></thead>
          <tbody>
            {(history?.events ?? []).map((e) => (
              <tr key={e.eventId}>
                <td>{e.occurredAt?.slice(0, 19).replace("T", " ")}</td>
                <td>{e.eventType}</td>
                <td>{e.actorId ?? "—"}</td>
                <td>{e.resultingStatus ?? "—"}</td>
              </tr>
            ))}
            {(history?.events ?? []).length === 0 && (
              <tr><td colSpan={4} className="empty">No events.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
