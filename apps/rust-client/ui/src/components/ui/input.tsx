import * as React from "react";
import { cn } from "@/lib/cn";

export function Input({ className, ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-9 w-full rounded-md border border-border bg-panelAlt px-3 text-sm text-foreground outline-none transition focus:border-slate-400",
        className,
      )}
      {...props}
    />
  );
}
