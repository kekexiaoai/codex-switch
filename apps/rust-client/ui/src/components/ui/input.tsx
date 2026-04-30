import * as React from "react";
import { cn } from "@/lib/cn";

export function Input({ className, ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-8 w-full rounded-md border border-border bg-panel px-2.5 text-[12px] text-foreground outline-none transition focus:border-slate-500",
        className,
      )}
      {...props}
    />
  );
}
