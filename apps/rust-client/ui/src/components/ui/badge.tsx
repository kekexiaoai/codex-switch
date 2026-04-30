import * as React from "react";
import { cn } from "@/lib/cn";

export function Badge({ className, ...props }: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-sm border border-border bg-panelAlt px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-[0.04em] text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}
