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
      className={`flex items-start justify-between mb-8 ${className || ''}`}
      {...props}
    >
      <div>
        <h1 className="text-4xl font-bold text-safe-slate">{title}</h1>
        {description && <p className="text-gray-600 mt-1">{description}</p>}
      </div>
      {action && <div className="flex gap-3">{action}</div>}
    </div>
  )
);

PageHeader.displayName = 'PageHeader';
