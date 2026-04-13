'use client';

import React, { useState } from 'react';

export interface DialogProps {
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: React.ReactNode;
}

export interface DialogContentProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
}

export interface DialogHeaderProps extends React.HTMLAttributes<HTMLDivElement> {}

export interface DialogTitleProps extends React.HTMLAttributes<HTMLHeadingElement> {}

export interface DialogDescriptionProps extends React.HTMLAttributes<HTMLParagraphElement> {}

const DialogContext = React.createContext<{ open: boolean; onOpenChange: (open: boolean) => void } | undefined>(undefined);

export const Dialog = ({ open: controlledOpen, onOpenChange, children }: DialogProps) => {
  const [internalOpen, setInternalOpen] = useState(controlledOpen || false);
  const open = controlledOpen !== undefined ? controlledOpen : internalOpen;
  const handleOpenChange = onOpenChange || setInternalOpen;

  return (
    <DialogContext.Provider value={{ open, onOpenChange: handleOpenChange }}>
      {children}
    </DialogContext.Provider>
  );
};

export const DialogTrigger = React.forwardRef<HTMLButtonElement, React.ButtonHTMLAttributes<HTMLButtonElement>>(
  ({ onClick, ...props }, ref) => {
    const context = React.useContext(DialogContext);
    if (!context) throw new Error('DialogTrigger must be used within Dialog');

    return (
      <button
        ref={ref}
        onClick={(e) => {
          context.onOpenChange(true);
          onClick?.(e);
        }}
        {...props}
      />
    );
  }
);
DialogTrigger.displayName = 'DialogTrigger';

export const DialogContent = React.forwardRef<HTMLDivElement, DialogContentProps>(
  ({ className, children, ...props }, ref) => {
    const context = React.useContext(DialogContext);
    if (!context) throw new Error('DialogContent must be used within Dialog');

    if (!context.open) return null;

    return (
      <>
        <div className="fixed inset-0 z-40 bg-black/50" onClick={() => context.onOpenChange(false)} />
        <div
          ref={ref}
          className={`fixed left-1/2 top-1/2 z-50 w-full max-w-lg -translate-x-1/2 -translate-y-1/2 rounded-lg border border-slate-200 bg-white p-6 shadow-lg ${className || ''}`}
          {...props}
        >
          {children}
          <button
            onClick={() => context.onOpenChange(false)}
            className="absolute right-4 top-4 text-slate-500 hover:text-slate-700"
          >
            ✕
          </button>
        </div>
      </>
    );
  }
);
DialogContent.displayName = 'DialogContent';

export const DialogHeader = ({ className, ...props }: DialogHeaderProps) => (
  <div className={`flex flex-col space-y-1.5 ${className || ''}`} {...props} />
);

export const DialogTitle = ({ className, ...props }: DialogTitleProps) => (
  <h2 className={`text-lg font-semibold ${className || ''}`} {...props} />
);

export const DialogDescription = ({ className, ...props }: DialogDescriptionProps) => (
  <p className={`text-sm text-slate-600 ${className || ''}`} {...props} />
);
