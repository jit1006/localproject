import { useEffect, useState } from "react";
import { api, ApiError } from "../api/client";

interface Run {
  run_id: number;
  run_kind: string;
  scope_key: string;
  status: string;
  started_at: string | null;
}

export function ReconciliationPage() {
  const [runs, setRuns] = useState<Run[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({ run_kind: "INVENTORY", scope_key: "" });

  const load = () =>
    api.get<Run[]>("/reconciliations").then(setRuns).catch((e) => setError(e.message));
  useEffect(() => void load(), []);

  const start = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      await api.post("/reconciliations", { ...form, parameters: {} });
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Failed to start run");
    }
  };

  return (
    <section>
      <h2>Reconciliation</h2>
      {error && <p className="error">{error}</p>}

      <form className="card" onSubmit={start}>
        <h3>Start a run</h3>
        <div className="form-grid">
          <label>
            Kind
            <select value={form.run_kind} onChange={(e) => setForm({ ...form, run_kind: e.target.value })}>
              <option>INVENTORY</option>
              <option>INVOICE</option>
              <option>CERTIFICATE</option>
              <option>DATA_QUALITY</option>
            </select>
          </label>
          <label>
            Scope key
            <input
              required
              placeholder="e.g. VND-001|2026-01-01"
              value={form.scope_key}
              onChange={(e) => setForm({ ...form, scope_key: e.target.value })}
            />
          </label>
        </div>
        <button type="submit">Run</button>
        <p className="muted">
          The run/exception framework and idempotency are implemented; the three full detection
          engines are the next increment (see docs/design.md).
        </p>
      </form>

      <table className="data-table">
        <thead>
          <tr>
            <th>Run</th>
            <th>Kind</th>
            <th>Scope</th>
            <th>Status</th>
            <th>Started</th>
          </tr>
        </thead>
        <tbody>
          {runs.length === 0 && (
            <tr>
              <td colSpan={5} className="empty">No runs yet.</td>
            </tr>
          )}
          {runs.map((r) => (
            <tr key={r.run_id}>
              <td>{r.run_id}</td>
              <td>{r.run_kind}</td>
              <td>{r.scope_key}</td>
              <td>{r.status}</td>
              <td>{r.started_at?.slice(0, 19).replace("T", " ")}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
