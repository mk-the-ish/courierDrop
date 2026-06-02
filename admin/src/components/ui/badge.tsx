import React from 'react';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'secondary' | 'outline' | 'success' | 'warning' | 'error';
}

export const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, variant = 'default', ...props }, ref) => {
    const variantStyles = {
      default: 'bg-orange-accent/15 text-orange-300 border border-orange-accent/30',
      secondary: 'bg-white/10 text-slate-100 border border-white/10',
      outline: 'border border-white/15 text-slate-200 bg-transparent',
      success: 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/25',
      warning: 'bg-orange-light/15 text-orange-200 border border-orange-light/25',
      error: 'bg-rose-500/15 text-rose-300 border border-rose-500/25',
    };

    return (
      <span
        ref={ref}
        className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold backdrop-blur ${variantStyles[variant]} ${className || ''}`}
        {...props}
      />
    );
  }
);

Badge.displayName = 'Badge';
