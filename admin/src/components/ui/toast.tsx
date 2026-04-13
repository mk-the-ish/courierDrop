import React from 'react';

export type ToastVariant = 'default' | 'destructive';

export interface ToastProps extends React.HTMLAttributes<HTMLDivElement> {
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  variant?: ToastVariant;
}

export type ToastActionElement = React.ReactElement;

export const Toast = React.forwardRef<HTMLDivElement, ToastProps>(
  ({ className, variant = 'default', ...props }, ref) => {
    const variantStyles =
      variant === 'destructive'
        ? 'border-red-200 bg-red-50 text-red-900'
        : 'border-slate-200 bg-white text-slate-900';

    return (
      <div
        ref={ref}
        className={`relative flex w-80 items-start gap-3 rounded-lg border p-4 shadow-sm ${variantStyles} ${className || ''}`}
        {...props}
      />
    );
  }
);

Toast.displayName = 'Toast';

export const ToastTitle = ({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) => (
  <h2 className={`text-sm font-semibold ${className || ''}`} {...props} />
);

export const ToastDescription = ({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) => (
  <p className={`text-xs text-slate-600 ${className || ''}`} {...props} />
);

export const ToastAction = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={`ml-auto ${className || ''}`} {...props} />
);

export const ToastClose = ({ className, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) => (
  <button
    type="button"
    className={`ml-auto text-xs text-slate-500 hover:text-slate-700 ${className || ''}`}
    {...props}
  />
);
