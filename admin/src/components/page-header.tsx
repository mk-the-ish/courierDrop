import React from 'react';

export interface PageHeaderProps extends React.HTMLAttributes<HTMLDivElement> {
  title: string;
  description?: string;
  action?: React.ReactNode;
}

export const PageHeader = React.forwardRef<HTMLDivElement, PageHeaderProps>(
  ({ title, description, action, className, ...props }, ref) => (
    <div
      ref={ref}
      className={`flex flex-col gap-4 md:flex-row md:items-start md:justify-between ${className || ''}`}
      {...props}
    >
      <div>
        <p className="micro-label mb-2">DropCity Console</p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-50 md:text-4xl">{title}</h1>
        {description && <p className="mt-2 max-w-3xl text-sm text-slate-400 md:text-base">{description}</p>}
      </div>
      {action && <div className="flex gap-3">{action}</div>}
    </div>
  )
);

PageHeader.displayName = 'PageHeader';
