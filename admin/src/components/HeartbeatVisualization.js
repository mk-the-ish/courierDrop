import React, { useState, useEffect } from 'react';

interface HeartbeatItemProps {
  id: string;
  name: string;
  state: 'active' | 'missed' | 'alert';
  lastUpdate?: string;
}

const stateConfig = {
  active: {
    color: '#22c55e',
    bgColor: 'bg-green-50',
    textColor: 'text-green-700',
    label: 'Active Heartbeat',
    icon: '💚',
  },
  missed: {
    color: '#FFBF00',
    bgColor: 'bg-yellow-50',
    textColor: 'text-yellow-700',
    label: 'Missed Frequency',
    icon: '⚠️',
  },
  alert: {
    color: '#ef4444',
    bgColor: 'bg-red-50',
    textColor: 'text-red-700',
    label: 'Watchdog Alert',
    icon: '🚨',
  },
};

export function HeartbeatItem({ id, name, state, lastUpdate }: HeartbeatItemProps) {
  const config = stateConfig[state];

  return (
    <div className={`${config.bgColor} border-2 rounded-lg p-4 transition-all duration-300`} style={{ borderColor: config.color }}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-2xl">{config.icon}</span>
          <div>
            <h4 className={`font-semibold ${config.textColor}`}>{name}</h4>
            <p className="text-sm text-gray-600">{config.label}</p>
          </div>
        </div>
        {state === 'active' && (
          <div className="relative w-8 h-8">
            <div
              className="absolute inset-0 rounded-full animate-pulse"
              style={{ backgroundColor: config.color, opacity: 0.3 }}
            />
            <div className="absolute inset-2 rounded-full" style={{ backgroundColor: config.color }} />
          </div>
        )}
      </div>
      {lastUpdate && <p className="text-xs text-gray-500 mt-2">Last update: {lastUpdate}</p>}
    </div>
  );
}

interface HeartbeatVisualizationProps {
  items: HeartbeatItemProps[];
  title?: string;
}

export default function HeartbeatVisualization({ items, title = 'System Heartbeat' }: HeartbeatVisualizationProps) {
  return (
    <div className="card p-6">
      <h3 className="text-lg font-bold text-safe-slate mb-6 flex items-center gap-2">
        <div className="w-3 h-3 bg-transit-teal rounded-full animate-pulse" />
        {title}
      </h3>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {items.map((item) => (
          <HeartbeatItem key={item.id} {...item} />
        ))}
      </div>
    </div>
  );
}
