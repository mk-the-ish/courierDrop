import type { ReactNode } from 'react';

type PageHeaderProps = {
  title: string;
  actions?: ReactNode;
};

export default function PageHeader({ title, actions }: PageHeaderProps) {
  return (
    <div className="flex min-h-14 items-center justify-between gap-4 py-4">
      <h1 className="font-headline text-2xl font-semibold tracking-tight">
        {title}
      </h1>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
