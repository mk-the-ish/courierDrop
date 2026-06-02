import React from 'react';
import { LucideIcon } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  icon?: LucideIcon;
  description?: string;
  trend?: number;
  color?: 'teal' | 'slate' | 'amber' | 'green' | 'red';
}

export default function StatCard({
  title,
  value,
  icon: Icon,
  description,
  trend,
  color = 'teal',
}: StatCardProps) {
  const colorMap = {
    teal: 'bg-transit-teal/15 text-teal-300 border border-transit-teal/25',
    slate: 'bg-white/8 text-slate-200 border border-white/10',
    amber: 'bg-orange-accent/15 text-orange-300 border border-orange-accent/30',
    green: 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/25',
    red: 'bg-rose-500/15 text-rose-300 border border-rose-500/25',
  };

  return (
    <div className="bento-card p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="micro-label">{title}</p>
          <p className="mt-2 text-3xl font-semibold tracking-tight text-slate-50">{value}</p>
          {description && <p className="mt-2 text-xs text-slate-400">{description}</p>}
          {trend !== undefined && (
            <p className={`mt-3 text-sm font-medium ${trend > 0 ? 'text-emerald-300' : 'text-rose-300'}`}>
              {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}%
            </p>
          )}
        </div>
        {Icon && (
          <div className={`rounded-xl border px-3 py-3 ${colorMap[color]}`}>
            <Icon size={24} />
          </div>
        )}
      </div>
    </div>
  );
}
