export default function StatCard({ title, value, icon: Icon, description, trend, color = 'teal' }) {
  const colorMap = {
    teal: 'bg-transit-teal/10 text-transit-teal',
    slate: 'bg-safe-slate/10 text-safe-slate',
    amber: 'bg-alert-amber/10 text-alert-amber',
    green: 'bg-green-100 text-green-600',
    red: 'bg-red-100 text-red-600',
  };

  return (
    <div className="card p-6">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-gray-600 text-sm font-medium">{title}</p>
          <p className="text-3xl font-bold text-safe-slate mt-2">{value}</p>
          {description && (
            <p className="text-xs text-gray-500 mt-2">{description}</p>
          )}
          {trend && (
            <p className={`text-sm mt-2 ${trend > 0 ? 'text-heartbeat-active' : 'text-heartbeat-alert'}`}>
              {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}%
            </p>
          )}
        </div>
        {Icon && (
          <div className={`p-3 rounded-lg ${colorMap[color]}`}>
            <Icon size={24} />
          </div>
        )}
      </div>
    </div>
  );
}
