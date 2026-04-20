import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { DiagnosticsEvent } from "@/lib/tauri";

export function DiagnosticsView({ diagnostics }: { diagnostics: DiagnosticsEvent[] }) {
  return (
    <Card className="h-full">
      <CardHeader>
        <div>
          <CardTitle>Diagnostics</CardTitle>
          <CardDescription>只显示经过敏感信息过滤的安全日志行。</CardDescription>
        </div>
      </CardHeader>
      <CardContent className="h-[calc(100%-76px)] overflow-auto">
        {diagnostics.length === 0 ? (
          <div className="rounded-xl border border-dashed border-border bg-panelAlt p-5 text-sm text-muted-foreground">
            当前没有诊断日志。
          </div>
        ) : (
          <div className="space-y-2">
            {diagnostics.map((event, index) => (
              <div key={`${event.category}-${index}`} className="rounded-xl border border-border bg-panelAlt px-4 py-3">
                <div className="text-[11px] uppercase tracking-[0.12em] text-muted-foreground">{event.category}</div>
                <div className="mt-2 font-mono text-sm leading-6">{event.message}</div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
