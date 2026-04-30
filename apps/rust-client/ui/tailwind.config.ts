import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        border: "hsl(var(--border))",
        panel: "hsl(var(--panel))",
        panelAlt: "hsl(var(--panel-alt))",
        muted: "hsl(var(--muted))",
        mutedForeground: "hsl(var(--muted-foreground))",
        accent: "hsl(var(--accent))",
        accentForeground: "hsl(var(--accent-foreground))",
        success: "hsl(var(--success))",
        warning: "hsl(var(--warning))",
        danger: "hsl(var(--danger))",
      },
      borderRadius: {
        lg: "var(--radius-lg)",
        md: "var(--radius-md)",
        sm: "var(--radius-sm)",
      },
      boxShadow: {
        panel: "0 1px 2px rgba(39, 47, 59, 0.08)",
        window: "0 22px 54px rgba(39, 47, 59, 0.16)",
      },
      fontFamily: {
        sans: ["SF Pro Text", "Segoe UI", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
