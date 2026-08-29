import * as Label from "@radix-ui/react-label";

export function Field({ label, htmlFor, className, children }) {
  return (
    <div className={className}>
      <Label.Root htmlFor={htmlFor} className="mb-2 block text-xs font-medium text-secondary">
        {label}
      </Label.Root>
      {children}
    </div>
  );
}
