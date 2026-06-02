"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, BookOpen, Image as ImageIcon, MapPin, ShieldCheck } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type Dispute = {
  id: string;
  parcel_id: string;
  courier_id: string;
  deviation_type: string;
  duration_seconds: number;
  created_at: string;
  resolution_status?: string;
  resolution_notes?: string;
};

type EvidencePayload = {
  dispute: Dispute;
  parcel: any;
  evidence: {
    handshake_events: any[];
    tracking_logs: any[];
    photos: {
      pickup: string | null;
      dropoff: string | null;
      handshake: string[];
    };
  };
  audit_trail: any[];
};

export default function DisputesPage() {
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [status, setStatus] = useState<"OPEN" | "ALL" | "ESCALATED">("OPEN");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [evidence, setEvidence] = useState<EvidencePayload | null>(null);
  const [decision, setDecision] = useState<"APPROVE" | "REFUND" | "PARTIAL" | "ESCALATE">("APPROVE");
  const [notes, setNotes] = useState("");
  const [partialAmount, setPartialAmount] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "" : "";

  async function loadDisputes() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${baseUrl}/admin/disputes?status=${status}&limit=150`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });
      if (!res.ok) throw new Error(`Failed loading disputes: ${res.status}`);
      const data = await res.json();
      const nextDisputes = data.disputes || [];
      setDisputes(nextDisputes);
      if (!selectedId && nextDisputes[0]?.id) {
        await loadEvidence(nextDisputes[0].id);
      }
    } catch (err: any) {
      setError(err.message || "Failed to load disputes");
    } finally {
      setLoading(false);
    }
  }

  async function loadEvidence(disputeId: string) {
    setError(null);
    try {
      const res = await fetch(`${baseUrl}/admin/disputes/${disputeId}/evidence`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });
      if (!res.ok) throw new Error(`Failed loading evidence: ${res.status}`);
      const data = await res.json();
      setEvidence(data);
      setSelectedId(disputeId);
    } catch (err: any) {
      setError(err.message || "Failed to load evidence");
    }
  }

  async function resolveDispute() {
    if (!selectedId) return;
    if (!notes.trim()) {
      setError("Resolution notes are required.");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch(`${baseUrl}/admin/disputes/${selectedId}/resolve`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          resolution: decision,
          notes: notes.trim(),
          partialAmount: decision === "PARTIAL" ? Number(partialAmount || 0) : null,
        }),
      });
      if (!res.ok) throw new Error(`Resolve failed: ${res.status}`);
      setNotes("");
      setPartialAmount("");
      await Promise.all([loadDisputes(), loadEvidence(selectedId)]);
    } catch (err: any) {
      setError(err.message || "Resolve failed");
    } finally {
      setSubmitting(false);
    }
  }

  useEffect(() => {
    loadDisputes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  const selectedDispute = useMemo(() => disputes.find((d) => d.id === selectedId) || null, [disputes, selectedId]);
  const openCount = disputes.filter((dispute) => (dispute.resolution_status || "OPEN") === "OPEN").length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Conflict Resolution"
        description="Inspect handoff failures, review evidence, and record the final audit trail in one view."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Open Disputes" value={openCount} icon={AlertTriangle} color="amber" />
        <StatCard title="Queued Cases" value={disputes.length} icon={BookOpen} color="teal" />
        <StatCard title="Selected" value={selectedDispute ? "1" : "0"} icon={ShieldCheck} color="green" />
      </div>

      {error && (
        <div className="flex gap-3 rounded-2xl border border-rose-500/20 bg-rose-500/10 p-4 text-sm text-rose-200">
          <AlertTriangle className="mt-0.5 h-5 w-5 flex-shrink-0 text-rose-300" />
          <p>{error}</p>
        </div>
      )}

      <div className="grid gap-6 xl:grid-cols-[0.8fr_1.2fr]">
        <Card>
          <CardHeader>
            <p className="micro-label">Case Queue</p>
            <CardTitle>Disputes ({disputes.length})</CardTitle>
            <CardDescription>Select a case to inspect evidence and resolution details.</CardDescription>
            <div className="flex flex-wrap gap-2 pt-2">
              <Button variant={status === "OPEN" ? "default" : "outline"} onClick={() => setStatus("OPEN")} size="sm">
                Open
              </Button>
              <Button
                variant={status === "ESCALATED" ? "default" : "outline"}
                onClick={() => setStatus("ESCALATED")}
                size="sm"
              >
                Escalated
              </Button>
              <Button variant={status === "ALL" ? "default" : "outline"} onClick={() => setStatus("ALL")} size="sm">
                All
              </Button>
            </div>
          </CardHeader>
          <CardContent className="space-y-3 max-h-[72vh] overflow-auto">
            {loading ? (
              <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
                Loading disputes...
              </div>
            ) : (
              disputes.map((dispute) => (
                <button
                  key={dispute.id}
                  onClick={() => loadEvidence(dispute.id)}
                  className={`w-full rounded-2xl border p-4 text-left transition ${
                    selectedId === dispute.id
                      ? "border-orange-accent/40 bg-orange-accent/10"
                      : "border-white/10 bg-white/5 hover:bg-white/10"
                  }`}
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="font-medium text-slate-100">Parcel {dispute.parcel_id?.slice(0, 8)}...</div>
                      <div className="mt-1 text-xs text-slate-500">{new Date(dispute.created_at).toLocaleString()}</div>
                    </div>
                    <Badge variant={dispute.resolution_status ? "secondary" : "warning"}>
                      {dispute.resolution_status || "OPEN"}
                    </Badge>
                  </div>
                  <div className="mt-2 text-sm text-slate-300">{dispute.deviation_type}</div>
                </button>
              ))
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <p className="micro-label">Evidence Board</p>
            <CardTitle>Evidence Panel</CardTitle>
            <CardDescription>Photos, GPS/timestamps, and immutable audit history.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4 max-h-[72vh] overflow-auto">
            {!selectedDispute && <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">Select a dispute.</div>}

            {selectedDispute && (
              <>
                <div className="grid gap-3 md:grid-cols-3">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2">Dispute ID</div>
                    <p className="text-sm text-slate-100">{selectedDispute.id}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2">Courier</div>
                    <p className="text-sm text-slate-100">{selectedDispute.courier_id || "-"}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2">Type</div>
                    <p className="text-sm text-slate-100">{selectedDispute.deviation_type}</p>
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2 flex items-center gap-2">
                      <ImageIcon size={14} /> Pickup Photo
                    </div>
                    <p className="break-all text-xs text-slate-300">{evidence?.evidence.photos.pickup || "-"}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2 flex items-center gap-2">
                      <ImageIcon size={14} /> Dropoff Photo
                    </div>
                    <p className="break-all text-xs text-slate-300">{evidence?.evidence.photos.dropoff || "-"}</p>
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2 flex items-center gap-2">
                      <MapPin size={14} /> Recent Handshakes
                    </div>
                    <div className="space-y-2">
                      {(evidence?.evidence.handshake_events || []).slice(0, 6).map((event: any) => (
                        <div key={event.id} className="rounded-xl border border-white/10 bg-slate-950/60 p-3 text-xs text-slate-300">
                          {event.step} • {event.status} • {new Date(event.created_at).toLocaleString()}
                        </div>
                      ))}
                    </div>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2 flex items-center gap-2">
                      <MapPin size={14} /> Recent Tracking Logs
                    </div>
                    <div className="space-y-2">
                      {(evidence?.evidence.tracking_logs || []).slice(0, 6).map((log: any) => (
                        <div key={log.id} className="rounded-xl border border-white/10 bg-slate-950/60 p-3 text-xs text-slate-300">
                          {new Date(log.created_at).toLocaleString()} • onCorridor={String(log.is_on_corridor)} • speed={log.speed_kmh ?? "-"}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="micro-label mb-3">Resolution Action</div>
                  <div className="flex flex-wrap gap-2">
                    {(["APPROVE", "REFUND", "PARTIAL", "ESCALATE"] as const).map((value) => (
                      <Button key={value} size="sm" variant={decision === value ? "default" : "outline"} onClick={() => setDecision(value)}>
                        {value}
                      </Button>
                    ))}
                  </div>
                  {decision === "PARTIAL" && (
                    <Input
                      placeholder="Partial refund amount"
                      value={partialAmount}
                      onChange={(e) => setPartialAmount(e.target.value)}
                      className="mt-3"
                    />
                  )}
                  <textarea
                    placeholder="Resolution notes (required)"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    className="mt-3 min-h-[96px] w-full rounded-xl border border-white/10 bg-slate-950/60 p-3 text-sm text-slate-100 outline-none focus:border-orange-accent"
                  />
                  <div className="mt-3">
                    <Button onClick={resolveDispute} disabled={submitting}>
                      {submitting ? "Submitting..." : "Submit Resolution"}
                    </Button>
                  </div>
                </div>

                <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="micro-label mb-3">Immutable Audit Trail</div>
                  <div className="space-y-2">
                    {(evidence?.audit_trail || []).length === 0 && (
                      <div className="text-xs text-slate-400">No audit entries yet.</div>
                    )}
                    {(evidence?.audit_trail || []).map((entry: any) => (
                      <div key={entry.id} className="rounded-xl border border-white/10 bg-slate-950/60 p-3 text-xs text-slate-300">
                        {entry.decision} • {new Date(entry.created_at).toLocaleString()} • admin={entry.admin_id || "-"}
                        {entry.notes ? ` • ${entry.notes}` : ""}
                      </div>
                    ))}
                  </div>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
