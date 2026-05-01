import { Clock3, Database, Gauge } from "lucide-react";
import type { ReactNode } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { UsageSnapshot } from "@/lib/tauri";

export function UsageView({ usage }: { usage?: UsageSnapshot | null }) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_340px] gap-5 overflow-hidden">
      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle>Usage Snapshot</CardTitle>
          <div className="text-[12px] font-semibold text-slate-500">{usage?.sourceLabel ?? "未刷新"}</div>
        </CardHeader>
        <CardContent>
          {usage ? (
            <div className="space-y-5">
              <UsageMeter
                label="5 小时窗口"
                value={usage.fiveHour.percentUsed}
                helper={new Date(usage.fiveHour.resetsAt).toLocaleString()}
              />
              <UsageMeter
                label="Weekly 窗口"
                value={usage.weekly.percentUsed}
                helper={new Date(usage.weekly.resetsAt).toLocaleString()}
              />
            </div>
          ) : (
            <div className="desktop-pane p-8 text-center text-[13px] text-slate-500">暂无可展示数据</div>
          )}
        </CardContent>
      </Card>
      <div className="space-y-5">
        <InfoCard icon={<Gauge className="h-5 w-5" />} label="数据源" value={usage?.sourceLabel ?? "Unknown"} />
        <InfoCard
          icon={<Clock3 className="h-5 w-5" />}
          label="更新时间"
          value={usage ? new Date(usage.updatedAt).toLocaleString() : "Never"}
        />
        <InfoCard icon={<Database className="h-5 w-5" />} label="模式" value="API / Local / Cache" />
      </div>
    </div>
  );
}

function UsageMeter({ label, value, helper }: { label: string; value: number; helper: string }) {
  const percent = Math.max(0, Math.min(100, value));
  const warning = percent > 60 && percent < 85;

  return (
    <div className="desktop-pane p-5">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[16px] font-black tracking-[-0.04em]">{label}</div>
          <div className="mt-1 text-[12px] font-medium text-slate-500">{helper}</div>
        </div>
        <div className={warning ? "text-[28px] font-black text-amber-500" : "text-[28px] font-black text-emerald-500"}>
          {percent}%
        </div>
      </div>
      <div className="usage-track mt-5 h-3">
        <div className={warning ? "usage-fill usage-fill-warning" : "usage-fill"} style={{ width: `${percent}%` }} />
      </div>
      <div className="mt-2 text-right text-[12px] font-semibold text-slate-500">已重置</div>
    </div>
  );
}

function InfoCard({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <Card className="p-5">
      <div className="flex items-center gap-4">
        <div className="grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br from-blue-50 to-cyan-50 text-blue-600">
          {icon}
        </div>
        <div className="min-w-0">
          <div className="text-[12px] font-bold text-slate-500">{label}</div>
          <div className="mt-1 truncate text-[15px] font-black tracking-[-0.03em]">{value}</div>
        </div>
      </div>
    </Card>
  );
}
