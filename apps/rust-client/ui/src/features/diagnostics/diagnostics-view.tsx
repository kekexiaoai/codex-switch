import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { DiagnosticsEvent } from "@/lib/tauri";

export function DiagnosticsView({ diagnostics }: { diagnostics: DiagnosticsEvent[] }) {
  return (
    <Card className="h-full overflow-hidden">
      <CardHeader>
        <CardTitle>Diagnostics</CardTitle>
        <div className="text-[12px] font-semibold text-slate-500">{diagnostics.length} events</div>
      </CardHeader>
      <CardContent className="h-[calc(100%-72px)] overflow-auto p-3">
        {diagnostics.length === 0 ? (
          <div className="desktop-pane p-8 text-center text-[13px] text-slate-500">当前没有诊断日志</div>
        ) : (
          <div className="space-y-2 font-mono">
            {diagnostics.map((event, index) => (
              <div key={`${event.category}-${index}`} className="desktop-row grid grid-cols-[150px_minmax(0,1fr)] gap-4 px-4 py-3">
                <div className="truncate text-[11px] uppercase tracking-[0.04em] text-muted-foreground">
                  {event.category}
                </div>
                <div className="min-w-0 break-words text-[12px] leading-5">{event.message}</div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
