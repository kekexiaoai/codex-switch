import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-1.5 rounded-md border text-[12px] font-medium transition-colors disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        default: "border-slate-700 bg-slate-800 px-2.5 py-1.5 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.14)] hover:bg-slate-700",
        secondary: "border-border bg-panel px-2.5 py-1.5 text-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.65)] hover:bg-panelAlt",
        ghost: "border-transparent bg-transparent px-2 py-1.5 text-muted-foreground hover:bg-panelAlt hover:text-foreground",
        danger: "border-rose-700 bg-rose-600 px-2.5 py-1.5 text-white hover:bg-rose-700",
      },
      size: {
        default: "h-8",
        sm: "h-7 px-2 text-[11px]",
        lg: "h-9 px-3",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {}

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
