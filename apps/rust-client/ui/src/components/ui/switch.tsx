import * as React from "react";
import { cn } from "@/lib/cn";

interface SwitchProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  checked: boolean;
  onCheckedChange: (next: boolean) => void;
}

export function Switch({ checked, onCheckedChange, className, ...props }: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onCheckedChange(!checked)}
      className={cn(
        "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border border-border transition-colors",
        checked ? "bg-slate-800" : "bg-panel",
        className,
      )}
      {...props}
    >
      <span
        className={cn(
          "absolute left-0.5 h-4 w-4 rounded-full border border-black/10 bg-white shadow-sm transition-transform",
          checked && "translate-x-4",
        )}
      />
    </button>
  );
}
