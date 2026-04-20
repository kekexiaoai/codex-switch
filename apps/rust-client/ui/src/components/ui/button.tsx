import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-md border text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "border-transparent bg-foreground px-3 py-2 text-white hover:bg-slate-700",
        secondary: "border-border bg-panel px-3 py-2 text-foreground hover:bg-panelAlt",
        ghost: "border-transparent bg-transparent px-2 py-2 text-muted-foreground hover:bg-panelAlt hover:text-foreground",
        danger: "border-transparent bg-rose-600 px-3 py-2 text-white hover:bg-rose-700",
      },
      size: {
        default: "h-9",
        sm: "h-8 px-2.5 text-xs",
        lg: "h-10 px-4",
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
