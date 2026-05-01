import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-1.5 rounded-xl border text-[12px] font-semibold transition disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        default:
          "border-sky-500/40 bg-gradient-to-br from-blue-600 to-cyan-500 px-3 py-1.5 text-white shadow-[0_10px_22px_rgba(37,99,235,0.24),inset_0_1px_0_rgba(255,255,255,0.28)] hover:brightness-105",
        secondary:
          "border-slate-300/60 bg-white/66 px-3 py-1.5 text-slate-700 shadow-[inset_0_1px_0_rgba(255,255,255,0.82),0_8px_18px_rgba(67,88,116,0.10)] hover:bg-white/88",
        ghost:
          "border-transparent bg-transparent px-2 py-1.5 text-muted-foreground hover:bg-white/54 hover:text-foreground",
        danger:
          "border-rose-400/50 bg-gradient-to-br from-rose-500 to-orange-500 px-3 py-1.5 text-white hover:brightness-105",
      },
      size: {
        default: "h-8",
        sm: "h-8 px-2.5 text-[11px]",
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
