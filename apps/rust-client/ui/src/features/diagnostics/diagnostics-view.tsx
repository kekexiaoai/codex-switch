import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { DiagnosticsEvent } from "@/lib/tauri";

export function DiagnosticsView({ diagnostics }: { diagnostics: DiagnosticsEvent[] }) {
  return (
    <Card className="h-full overflow-hidden">
      <CardHeader className="h-11">
        <CardTitle>Diagnostics</CardTitle>
        <div className="text-[11px] text-muted-foreground">{diagnostics.length} events</div>
      </CardHeader>
      <CardContent className="h-[calc(100%-44px)] overflow-auto p-2">
        {diagnostics.length === 0 ? (
          <div className="desktop-pane p-4 text-[12px] text-muted-foreground">当前没有诊断日志</div>
        ) : (
          <div className="space-y-1 font-mono">
            {diagnostics.map((event, index) => (
              <div key={`${event.category}-${index}`} className="desktop-row grid grid-cols-[130px_minmax(0,1fr)] gap-3 px-2.5 py-2">
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
