import { useEffect, useState } from "react";

const defaultBaseUrl = "http://localhost:8080";

function formatTime(iso) {
  if (!iso) return "-";
  const time = new Date(iso);
  if (Number.isNaN(time.getTime())) return iso;
  return time.toLocaleString();
}

function formatAgo(iso) {
  if (!iso) return "-";
  const time = new Date(iso);
  if (Number.isNaN(time.getTime())) return iso;
  const diffSeconds = Math.floor((Date.now() - time.getTime()) / 1000);
  if (diffSeconds < 60) return `${diffSeconds}s ago`;
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

export default function ErrorsDashboard() {
  const [baseUrl, setBaseUrl] = useState(defaultBaseUrl);
  const [token, setToken] = useState("");

  // Filters
  const [daysFilter, setDaysFilter] = useState(7);
  const [deviceFilter, setDeviceFilter] = useState("");
  const [osFilter, setOsFilter] = useState("");

  // Data
  const [summary, setSummary] = useState(null);
  const [summaryStatus, setSummaryStatus] = useState("");
  const [errors, setErrors] = useState([]);
  const [errorsStatus, setErrorsStatus] = useState("");
  const [totalErrors, setTotalErrors] = useState(0);
  const [currentPage, setCurrentPage] = useState(0);
  const [pageSize] = useState(50);

  async function fetchSummary() {
    if (!baseUrl || !token) {
      setSummaryStatus("Base URL and token required.");
      return;
    }
    setSummaryStatus("Loading summary...");
    try {
      const response = await fetch(
        `${baseUrl}/admin/errors/summary?days=${daysFilter}`,
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || "Failed to fetch summary");
      }
      setSummary(data);
      setSummaryStatus("");
    } catch (error) {
      setSummaryStatus(error.message);
    }
  }

  async function fetchErrors() {
    if (!baseUrl || !token) {
      setErrorsStatus("Base URL and token required.");
      return;
    }
    setErrorsStatus("Loading errors...");
    try {
      const params = new URLSearchParams({
        limit: pageSize,
        offset: currentPage * pageSize,
        days: daysFilter
      });
      if (deviceFilter) params.append("device_model", deviceFilter);
      if (osFilter) params.append("os_version", osFilter);

      const response = await fetch(
        `${baseUrl}/admin/errors?${params.toString()}`,
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || "Failed to fetch errors");
      }
      setErrors(data.errors || []);
      setTotalErrors(data.total || 0);
      setErrorsStatus("");
    } catch (error) {
      setErrorsStatus(error.message);
    }
  }

  useEffect(() => {
    fetchSummary();
  }, [baseUrl, token, daysFilter]);

  useEffect(() => {
    setCurrentPage(0);
  }, [daysFilter, deviceFilter, osFilter]);

  useEffect(() => {
    fetchErrors();
  }, [baseUrl, token, daysFilter, deviceFilter, osFilter, currentPage]);

  const pageCount = Math.ceil(totalErrors / pageSize);

  return (
    <main className="container">
      <h1>Error Dashboard</h1>
      
      <nav style={{ marginBottom: "20px", display: "flex", gap: "10px" }}>
        <a href="/" style={{ padding: "8px 12px", background: "#0066cc", color: "white", borderRadius: "4px", textDecoration: "none" }}>Dashboard</a>
        <a href="/errors" style={{ padding: "8px 12px", background: "#dc3545", color: "white", borderRadius: "4px", textDecoration: "none" }}>Errors</a>
        <a href="/alerts" style={{ padding: "8px 12px", background: "#ff9800", color: "white", borderRadius: "4px", textDecoration: "none" }}>Alerts</a>
      </nav>

      <section className="card">
        <h2>Configuration</h2>
        <label>
          Backend URL
          <input
            type="text"
            value={baseUrl}
            onChange={(event) => setBaseUrl(event.target.value)}
          />
        </label>
        <label>
          Admin Token (Bearer)
          <input
            type="password"
            placeholder="Paste Firebase ID token"
            value={token}
            onChange={(event) => setToken(event.target.value)}
          />
        </label>
      </section>

      <section className="card">
        <h2>Filters</h2>
        <div className="filter-row">
          <label>
            Time Range (days)
            <input
              type="number"
              value={daysFilter}
              onChange={(event) => setDaysFilter(Number(event.target.value))}
              min="1"
              max="90"
            />
          </label>
          <label>
            Device Model
            <input
              type="text"
              placeholder="e.g. SM-G991B"
              value={deviceFilter}
              onChange={(event) => setDeviceFilter(event.target.value)}
            />
          </label>
          <label>
            OS Version
            <input
              type="text"
              placeholder="e.g. Android 12"
              value={osFilter}
              onChange={(event) => setOsFilter(event.target.value)}
            />
          </label>
          <button onClick={() => { setCurrentPage(0); fetchErrors(); }}>
            Apply Filters
          </button>
        </div>
      </section>

      {summary ? (
        <section className="card">
          <h2>Summary (Last {daysFilter} days)</h2>
          <div className="summary-grid">
            <div className="summary-card">
              <div className="summary-value">{summary.totalErrors}</div>
              <div className="summary-label">Total Errors</div>
            </div>
            <div className="summary-card">
              <div className="summary-value">
                {Object.keys(summary.byDevice).length}
              </div>
              <div className="summary-label">Unique Devices</div>
            </div>
            <div className="summary-card">
              <div className="summary-value">
                {Object.keys(summary.byOsVersion).length}
              </div>
              <div className="summary-label">Unique OS Versions</div>
            </div>
          </div>

          <div className="summary-section">
            <h3>Top Errors</h3>
            <div className="error-frequency-list">
              {summary.topErrors && summary.topErrors.length > 0 ? (
                summary.topErrors.map((error, idx) => (
                  <div className="error-frequency-item" key={idx}>
                    <div className="frequency-rank">#{idx + 1}</div>
                    <div className="frequency-info">
                      <div className="frequency-trace">
                        {error.stackTrace.split("\n")[0].substring(0, 80)}...
                      </div>
                      <div className="frequency-count">{error.count} occurrences</div>
                    </div>
                  </div>
                ))
              ) : (
                <p>No errors yet.</p>
              )}
            </div>
          </div>

          <div className="summary-section">
            <h3>Errors by Device</h3>
            <div className="breakdown-grid">
              {Object.entries(summary.byDevice)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 10)
                .map(([device, count]) => (
                  <div className="breakdown-card" key={device}>
                    <div className="breakdown-label">{device || "Unknown"}</div>
                    <div className="breakdown-value">{count}</div>
                  </div>
                ))}
            </div>
          </div>

          <div className="summary-section">
            <h3>Errors by OS Version</h3>
            <div className="breakdown-grid">
              {Object.entries(summary.byOsVersion)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 10)
                .map(([os, count]) => (
                  <div className="breakdown-card" key={os}>
                    <div className="breakdown-label">{os || "Unknown"}</div>
                    <div className="breakdown-value">{count}</div>
                  </div>
                ))}
            </div>
          </div>
        </section>
      ) : null}

      <section className="card">
        <h2>Recent Errors</h2>
        <div className="errors-header">
          <span className="status">{errorsStatus || `Showing ${errors.length} of ${totalErrors}`}</span>
          <button onClick={fetchErrors}>Refresh</button>
        </div>

        <div className="errors-list">
          {errors.length === 0 ? (
            <p>No errors found.</p>
          ) : null}
          {errors.map((error) => (
            <div className="error-item" key={error.id}>
              <div className="error-header">
                <div className="error-time">{formatTime(error.occurred_at)}</div>
                <div className="error-device">
                  {error.device_model || "Unknown Device"}
                </div>
              </div>
              <div className="error-trace">
                <code>{error.stack_trace}</code>
              </div>
              <div className="error-meta">
                <span>User: {error.user_id || "Anonymous"}</span>
                <span>OS: {error.os_version || "-"}</span>
                <span>Request ID: {error.request_id || "-"}</span>
              </div>
              {error.context ? (
                <div className="error-context">
                  <strong>Context:</strong>
                  <pre>{JSON.stringify(error.context, null, 2)}</pre>
                </div>
              ) : null}
            </div>
          ))}
        </div>

        {pageCount > 1 ? (
          <div className="pagination">
            <button
              onClick={() => setCurrentPage(Math.max(0, currentPage - 1))}
              disabled={currentPage === 0}
            >
              ← Previous
            </button>
            <span className="page-info">
              Page {currentPage + 1} of {pageCount}
            </span>
            <button
              onClick={() => setCurrentPage(Math.min(pageCount - 1, currentPage + 1))}
              disabled={currentPage >= pageCount - 1}
            >
              Next →
            </button>
          </div>
        ) : null}
      </section>
    </main>
  );
}
