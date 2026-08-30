import type { ReactNode } from "react";
import * as Label from "@radix-ui/react-label";

export type FieldProps = {
  label: ReactNode;
  htmlFor?: string;
  className?: string;
  children?: ReactNode;
};

export function Field({ label, htmlFor, className, children }: FieldProps) {
  return (
    <div className={className}>
      <Label.Root htmlFor={htmlFor} className="mb-2 block text-xs font-medium text-secondary">
        {label}
      </Label.Root>
      {children}
    </div>
  );
}
