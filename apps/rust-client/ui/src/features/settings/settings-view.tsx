import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import type { SettingsDto } from "@/lib/tauri";

export function SettingsView({
  settings,
  onChange,
}: {
  settings: SettingsDto;
  onChange: (settings: SettingsDto) => void;
}) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_340px] gap-5 overflow-hidden">
      <Card>
        <CardHeader>
          <CardTitle>偏好设置</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="desktop-pane p-4">
            <div className="flex items-center justify-between gap-4">
              <div>
                <div className="text-[15px] font-black tracking-[-0.03em]">Usage 数据源</div>
                <div className="mt-1 text-[12px] font-medium text-slate-500">自动优先远端，失败后回退本地日志</div>
              </div>
              <div className="flex rounded-2xl border border-slate-300/50 bg-white/54 p-1">
                <Button
                  size="sm"
                  variant={settings.usageSourceMode === "automatic" ? "default" : "ghost"}
                  onClick={() => onChange({ ...settings, usageSourceMode: "automatic" })}
                >
                  自动
                </Button>
                <Button
                  size="sm"
                  variant={settings.usageSourceMode === "localOnly" ? "default" : "ghost"}
                  onClick={() => onChange({ ...settings, usageSourceMode: "localOnly" })}
                >
                  本地
                </Button>
              </div>
            </div>
          </div>
          <SettingRow
            title="启用 Usage 刷新"
            description="允许刷新远端或本地 usage 快照"
            checked={settings.usageRefreshEnabled}
            onCheckedChange={(checked) => onChange({ ...settings, usageRefreshEnabled: checked })}
          />
          <SettingRow
            title="显示完整邮箱"
            description="账号列表和托盘使用完整邮箱"
            checked={settings.showFullEmail}
            onCheckedChange={(checked) => onChange({ ...settings, showFullEmail: checked })}
          />
          <SettingRow
            title="开机启动"
            description="随系统登录启动 Codex Switch"
            checked={settings.launchAtLogin}
            onCheckedChange={(checked) => onChange({ ...settings, launchAtLogin: checked })}
          />
        </CardContent>
      </Card>
      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle>存储</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-[12px] text-muted-foreground">
          <div className="desktop-pane p-3 text-[12px] leading-5">
            账号与 Codex 数据继续保存在 ~/.codex，界面偏好保存在 Tauri 应用配置目录。
          </div>
          <InfoRow label="Codex data" value="~/.codex" />
          <InfoRow label="Settings" value="App config" />
          <InfoRow label="Runtime" value="Tauri" />
        </CardContent>
      </Card>
    </div>
  );
}

function SettingRow({
  title,
  description,
  checked,
  onCheckedChange,
}: {
  title: string;
  description: string;
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
}) {
  return (
    <div className="desktop-pane flex items-center justify-between gap-4 px-4 py-4">
      <div>
        <div className="text-[15px] font-black tracking-[-0.03em]">{title}</div>
        <div className="mt-1 text-[12px] font-medium text-slate-500">{description}</div>
      </div>
      <Switch checked={checked} onCheckedChange={onCheckedChange} />
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-border pb-2 last:border-b-0 last:pb-0">
      <span>{label}</span>
      <span className="text-foreground">{value}</span>
    </div>
  );
}
