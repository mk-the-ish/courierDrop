'use client';

import { useToast } from '@/hooks/use-toast';
import { Toast, ToastAction, ToastClose, ToastDescription, ToastTitle } from '@/components/ui/toast';

export function Toaster() {
  const { toasts, dismiss } = useToast();

  return (
    <div id="toast-container" className="fixed top-4 right-4 z-50 flex flex-col gap-2">
      {toasts.map((toast) => (
        <Toast
          key={toast.id}
          open={toast.open}
          onOpenChange={toast.onOpenChange}
          variant={toast.variant}
        >
          <div className="flex-1">
            {toast.title && <ToastTitle>{toast.title}</ToastTitle>}
            {toast.description && <ToastDescription>{toast.description}</ToastDescription>}
          </div>
          {toast.action && <ToastAction>{toast.action}</ToastAction>}
          <ToastClose onClick={() => dismiss(toast.id)}>Close</ToastClose>
        </Toast>
      ))}
    </div>
  );
}
