'use client';

import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';

type Dispute = {
  id: string;
  parcel_id: string;
  courier_id: string;
  deviation_type: string;
  duration_seconds: number;
  created_at: string;
  resolution_status?: string;
  resolution_notes?: string;
  parsed_notes?: any;
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
  const [status, setStatus] = useState<'OPEN' | 'ALL' | 'ESCALATED'>('OPEN');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [evidence, setEvidence] = useState<EvidencePayload | null>(null);
  const [decision, setDecision] = useState<'APPROVE' | 'REFUND' | 'PARTIAL' | 'ESCALATE'>('APPROVE');
  const [notes, setNotes] = useState('');
  const [partialAmount, setPartialAmount] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const token = typeof window !== 'undefined'
    ? (localStorage.getItem('admin_token') || localStorage.getItem('adminToken') || '')
    : '';

  async function loadDisputes() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${baseUrl}/admin/disputes?status=${status}&limit=150`, {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });
      if (!res.ok) throw new Error(`Failed loading disputes: ${res.status}`);
      const data = await res.json();
      setDisputes(data.disputes || []);
    } catch (err: any) {
      setError(err.message || 'Failed to load disputes');
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
          'Content-Type': 'application/json',
        },
      });
      if (!res.ok) throw new Error(`Failed loading evidence: ${res.status}`);
      const data = await res.json();
      setEvidence(data);
      setSelectedId(disputeId);
    } catch (err: any) {
      setError(err.message || 'Failed to load evidence');
    }
  }

  async function resolveDispute() {
    if (!selectedId) return;
    if (!notes.trim()) {
      setError('Resolution notes are required.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch(`${baseUrl}/admin/disputes/${selectedId}/resolve`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          resolution: decision,
          notes: notes.trim(),
          partialAmount: decision === 'PARTIAL' ? Number(partialAmount || 0) : null,
        }),
      });
      if (!res.ok) throw new Error(`Resolve failed: ${res.status}`);
      setNotes('');
      setPartialAmount('');
      await Promise.all([loadDisputes(), loadEvidence(selectedId)]);
    } catch (err: any) {
      setError(err.message || 'Resolve failed');
    } finally {
      setSubmitting(false);
    }
  }

  useEffect(() => {
    loadDisputes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  const selectedDispute = useMemo(
    () => disputes.find((d) => d.id === selectedId) || null,
    [disputes, selectedId]
  );

  return (
    <div className="space-y-6 p-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Conflict Resolution</h1>
          <p className="text-slate-400">Resolve handoff failures and disputes with full evidence and audit trail.</p>
        </div>
        <div className="flex gap-2">
          <Button variant={status === 'OPEN' ? 'default' : 'outline'} onClick={() => setStatus('OPEN')}>Open</Button>
          <Button variant={status === 'ESCALATED' ? 'default' : 'outline'} onClick={() => setStatus('ESCALATED')}>Escalated</Button>
          <Button variant={status === 'ALL' ? 'default' : 'outline'} onClick={() => setStatus('ALL')}>All</Button>
        </div>
      </div>

      {error && <div className="text-red-400 text-sm">{error}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="bg-slate-800 border-slate-700">
          <CardHeader>
            <CardTitle className="text-white">Disputes ({disputes.length})</CardTitle>
            <CardDescription className="text-slate-400">Select a dispute to inspect evidence.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 max-h-[70vh] overflow-auto">
            {loading && <div className="text-slate-400">Loading...</div>}
            {!loading && disputes.map((d) => (
              <button
                key={d.id}
                onClick={() => loadEvidence(d.id)}
                className={`w-full text-left p-3 rounded border ${
                  selectedId === d.id ? 'border-blue-500 bg-slate-700' : 'border-slate-600 bg-slate-750'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="text-white font-medium">Parcel {d.parcel_id?.slice(0, 8)}...</div>
                  <Badge>{d.resolution_status || 'OPEN'}</Badge>
                </div>
                <div className="text-slate-300 text-sm mt-1">{d.deviation_type}</div>
                <div className="text-slate-400 text-xs mt-1">{new Date(d.created_at).toLocaleString()}</div>
              </button>
            ))}
          </CardContent>
        </Card>

        <Card className="bg-slate-800 border-slate-700">
          <CardHeader>
            <CardTitle className="text-white">Evidence Panel</CardTitle>
            <CardDescription className="text-slate-400">Photos, GPS/timestamps, and immutable audit history.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4 max-h-[70vh] overflow-auto">
            {!selectedDispute && <div className="text-slate-400">Select a dispute.</div>}
            {selectedDispute && (
              <>
                <div className="text-sm text-slate-300">
                  <div>Dispute ID: {selectedDispute.id}</div>
                  <div>Courier: {selectedDispute.courier_id || '-'}</div>
                  <div>Type: {selectedDispute.deviation_type}</div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3 rounded border border-slate-600">
                    <div className="text-xs text-slate-400">Pickup Photo</div>
                    <div className="text-xs text-slate-200 break-all">{evidence?.evidence.photos.pickup || '-'}</div>
                  </div>
                  <div className="p-3 rounded border border-slate-600">
                    <div className="text-xs text-slate-400">Dropoff Photo</div>
                    <div className="text-xs text-slate-200 break-all">{evidence?.evidence.photos.dropoff || '-'}</div>
                  </div>
                </div>

                <div>
                  <div className="text-sm text-white mb-2">Recent Handshake Events</div>
                  <div className="space-y-2">
                    {(evidence?.evidence.handshake_events || []).slice(0, 8).map((evt: any) => (
                      <div key={evt.id} className="text-xs p-2 border border-slate-600 rounded text-slate-300">
                        {evt.step} • {evt.status} • {new Date(evt.created_at).toLocaleString()}
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <div className="text-sm text-white mb-2">Recent Tracking Logs</div>
                  <div className="space-y-2">
                    {(evidence?.evidence.tracking_logs || []).slice(0, 8).map((log: any) => (
                      <div key={log.id} className="text-xs p-2 border border-slate-600 rounded text-slate-300">
                        {new Date(log.created_at).toLocaleString()} • onCorridor={String(log.is_on_corridor)} • speed={log.speed_kmh ?? '-'}
                      </div>
                    ))}
                  </div>
                </div>

                <div className="pt-3 border-t border-slate-700">
                  <div className="text-sm text-white mb-2">Resolution Action</div>
                  <div className="flex gap-2 mb-2">
                    {(['APPROVE', 'REFUND', 'PARTIAL', 'ESCALATE'] as const).map((value) => (
                      <Button
                        key={value}
                        size="sm"
                        variant={decision === value ? 'default' : 'outline'}
                        onClick={() => setDecision(value)}
                      >
                        {value}
                      </Button>
                    ))}
                  </div>
                  {decision === 'PARTIAL' && (
                    <Input
                      placeholder="Partial refund amount"
                      value={partialAmount}
                      onChange={(e) => setPartialAmount(e.target.value)}
                      className="mb-2"
                    />
                  )}
                  <textarea
                    placeholder="Resolution notes (required)"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    className="mb-2 min-h-[96px] w-full rounded-md border border-slate-600 bg-slate-700 p-2 text-sm text-white outline-none focus:border-blue-500"
                  />
                  <Button disabled={submitting} onClick={resolveDispute}>
                    {submitting ? 'Submitting...' : 'Submit Resolution'}
                  </Button>
                </div>

                <div className="pt-3 border-t border-slate-700">
                  <div className="text-sm text-white mb-2">Immutable Audit Trail</div>
                  <div className="space-y-2">
                    {(evidence?.audit_trail || []).length === 0 && (
                      <div className="text-xs text-slate-400">No audit entries yet.</div>
                    )}
                    {(evidence?.audit_trail || []).map((entry: any) => (
                      <div key={entry.id} className="text-xs p-2 border border-slate-600 rounded text-slate-300">
                        {entry.decision} • {new Date(entry.created_at).toLocaleString()} • admin={entry.admin_id || '-'}
                        {entry.notes ? ` • ${entry.notes}` : ''}
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
