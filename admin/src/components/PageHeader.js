export default function PageHeader({ title, actions }) {
  return (
    <div className="flex min-h-14 items-center justify-between gap-4 py-4">
      <h1 className="text-2xl font-semibold tracking-tight text-slate-900">
        {title}
      </h1>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
