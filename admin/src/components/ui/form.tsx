'use client';

import React from 'react';

export interface FormProps extends React.FormHTMLAttributes<HTMLFormElement> {}

export const Form = React.forwardRef<HTMLFormElement, FormProps>(
  ({ className, ...props }, ref) => (
    <form ref={ref} className={className} {...props} />
  )
);

Form.displayName = 'Form';

export const FormField = ({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={`space-y-2 ${className || ''}`} {...props}>
    {children}
  </div>
);

export const FormItem = FormField;

export const FormLabel = React.forwardRef<
  HTMLLabelElement,
  React.LabelHTMLAttributes<HTMLLabelElement>
>(({ className, ...props }, ref) => (
  <label ref={ref} className={`block text-sm font-medium text-slate-700 ${className || ''}`} {...props} />
));

FormLabel.displayName = 'FormLabel';

export const FormControl = ({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={className} {...props}>
    {children}
  </div>
);

export const FormDescription = ({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) => (
  <p className={`text-sm text-slate-500 ${className || ''}`} {...props} />
);

export const FormMessage = ({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) => (
  <p className={`text-sm font-medium text-red-600 ${className || ''}`} {...props} />
);
