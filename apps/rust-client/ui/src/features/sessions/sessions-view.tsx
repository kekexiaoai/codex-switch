import { useMemo, useState } from "react";
import { Clock3, FileText, Folder, MessageSquareText, RefreshCcw, Search, TerminalSquare } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/cn";
import type { CodexSessionDetail, CodexSessionListItem } from "@/lib/tauri";

const ALL_PROJECTS = "__all__";

export function SessionsView({
  sessions,
  projects,
  selectedSession,
  loading,
  onRefresh,
  onSelectSession,
}: {
  sessions: CodexSessionListItem[];
  projects: string[];
  selectedSession?: CodexSessionDetail | null;
  loading: boolean;
  onRefresh: () => void;
  onSelectSession: (sessionId: string) => void;
}) {
  const [query, setQuery] = useState("");
  const [project, setProject] = useState(ALL_PROJECTS);

  const filteredSessions = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return sessions.filter((session) => {
      const matchesProject = project === ALL_PROJECTS || session.project === project;
      if (!matchesProject) {
        return false;
      }
      if (!needle) {
        return true;
      }
      return [
        session.display,
        session.id,
        session.project,
        session.projectName,
      ].some((value) => value.toLowerCase().includes(needle));
    });
  }, [project, query, sessions]);

  const selectedId = selectedSession?.session.id;

  return (
    <div className="grid h-full min-h-0 grid-cols-[360px_minmax(0,1fr)] gap-4 overflow-hidden">
      <Card className="flex min-h-0 flex-col overflow-hidden">
        <div className="flex shrink-0 items-center justify-between gap-3 border-b border-slate-200/70 px-5 py-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <MessageSquareText className="h-4 w-4 text-blue-600" />
              <h2 className="m-0 text-[16px] font-black tracking-[-0.04em]">会话索引</h2>
            </div>
            <div className="mt-1 truncate text-[11px] font-semibold text-slate-400">
              来自 ~/.codex/history.jsonl 与 sessions 目录
            </div>
          </div>
          <Button variant="secondary" size="sm" onClick={onRefresh} disabled={loading}>
            <RefreshCcw className={cn("h-3.5 w-3.5", loading ? "animate-spin" : "")} />
            刷新
          </Button>
        </div>

        <div className="shrink-0 space-y-3 border-b border-slate-200/70 px-5 py-4">
          <label className="relative block">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              className="rounded-2xl bg-white/62 pl-8"
              placeholder="搜索提示词、项目或 Session ID"
            />
          </label>

          <div className="flex items-center gap-2">
            <span className="shrink-0 text-[11px] font-black uppercase tracking-[0.12em] text-slate-400">项目</span>
            <select
              value={project}
              onChange={(event) => setProject(event.target.value)}
              className="h-8 min-w-0 flex-1 rounded-2xl border border-slate-300/60 bg-white/66 px-3 text-[12px] font-semibold text-slate-700 outline-none shadow-[inset_0_1px_0_rgba(255,255,255,0.82)]"
              title={project === ALL_PROJECTS ? "全部项目" : project}
            >
              <option value={ALL_PROJECTS}>全部项目</option>
              {projects.map((item) => (
                <option key={item} value={item}>
                  {projectName(item)}
                </option>
              ))}
            </select>
            <Badge className="shrink-0 whitespace-nowrap border-blue-200 bg-blue-50 px-2 text-blue-700">
              {filteredSessions.length} / {sessions.length}
            </Badge>
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-auto px-3 py-3">
          {filteredSessions.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-300/70 bg-white/42 p-5 text-[13px] leading-6 text-slate-500">
              未找到匹配的历史会话。可以调整搜索词或项目筛选。
            </div>
          ) : null}
          <div className="space-y-2">
            {filteredSessions.map((session) => (
              <button
                key={session.id}
                type="button"
                onClick={() => onSelectSession(session.id)}
                className={cn(
                  "desktop-row w-full px-3 py-3 text-left",
                  selectedId === session.id ? "desktop-row-selected" : "",
                )}
              >
                <div className="mb-2 flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="line-clamp-2 text-[13px] font-black leading-5 tracking-[-0.03em] text-slate-900">
                      {session.display}
                    </div>
                  </div>
                  <Badge className="shrink-0 whitespace-nowrap border-blue-200 bg-blue-50 text-blue-700">
                    {session.messageCount}
                  </Badge>
                </div>
                <div className="flex min-w-0 items-center gap-2 text-[11px] font-semibold text-slate-500">
                  <Folder className="h-3.5 w-3.5 shrink-0 text-slate-400" />
                  <span className="truncate">{session.projectName || "未记录项目"}</span>
                </div>
                <div className="mt-1 flex min-w-0 items-center gap-2 text-[11px] text-slate-400">
                  <Clock3 className="h-3.5 w-3.5 shrink-0" />
                  <span>{formatDateTime(session.timestamp)}</span>
                </div>
              </button>
            ))}
          </div>
        </div>
      </Card>

      <Card className="flex min-h-0 flex-col overflow-hidden">
        {selectedSession ? (
          <>
            <div className="flex shrink-0 items-start justify-between gap-4 border-b border-slate-200/70 px-5 py-4">
              <div className="min-w-0">
                <div className="mb-2 flex items-center gap-2">
                  <FileText className="h-4 w-4 text-blue-600" />
                  <h2 className="m-0 truncate text-[16px] font-black tracking-[-0.04em]">
                    {selectedSession.session.display}
                  </h2>
                </div>
                <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-[11px] text-slate-500">
                  <MetaLine label="项目" value={selectedSession.session.project || "未记录"} />
                  <MetaLine label="时间" value={formatDateTime(selectedSession.session.timestamp)} />
                  <MetaLine label="消息" value={`${selectedSession.messages.length} 条`} />
                  <MetaLine label="ID" value={selectedSession.session.id} monospace />
                </div>
              </div>
            </div>

            <div className="min-h-0 flex-1 overflow-auto px-5 py-4">
              {selectedSession.messages.length === 0 ? (
                <div className="rounded-2xl border border-dashed border-slate-300/70 bg-white/42 p-6 text-[13px] leading-6 text-slate-500">
                  该会话只有 history 索引，暂未找到可读取的 rollout 详情文件。
                </div>
              ) : (
                <div className="space-y-3">
                  {selectedSession.messages.map((message, index) => (
                    <MessageBubble key={`${message.timestamp ?? "message"}-${index}`} message={message} />
                  ))}
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="grid h-full place-items-center p-8">
            <div className="max-w-md rounded-3xl border border-dashed border-slate-300/70 bg-white/42 p-8 text-center">
              <TerminalSquare className="mx-auto h-8 w-8 text-blue-500" />
              <div className="mt-4 text-[18px] font-black tracking-[-0.04em]">选择一个历史会话</div>
              <div className="mt-2 text-[13px] leading-6 text-slate-500">
                左侧展示 Codex 本地历史索引。选择会话后可查看用户输入、助手回复和工具调用摘要。
              </div>
            </div>
          </div>
        )}
      </Card>
    </div>
  );
}

function MessageBubble({ message }: { message: CodexSessionDetail["messages"][number] }) {
  const roleLabel = roleName(message.role);
  const isTool = message.role === "tool" || message.kind !== "message";
  const isUser = message.role === "user";
  const isBootstrapContext = isCodexBootstrapContext(message.text);
  return (
    <article
      className={cn(
        "max-w-[86%] rounded-2xl border px-4 py-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.74)]",
        isUser
          ? "ml-auto border-blue-200/80 bg-blue-50/70"
          : isTool
            ? "mr-auto border-slate-300/70 bg-slate-50/74"
            : "mr-auto border-emerald-100/80 bg-white/66",
      )}
    >
      <div className={cn("mb-2 flex items-center justify-between gap-3", isUser ? "flex-row-reverse" : "")}>
        <Badge
          className={cn(
            "whitespace-nowrap px-2",
            isUser
              ? "border-blue-300 bg-blue-50 text-blue-700"
              : isTool
                ? "border-slate-300 bg-slate-100 text-slate-600"
                : "border-emerald-300 bg-emerald-50 text-emerald-700",
          )}
        >
          {roleLabel}
        </Badge>
        <span className="text-[11px] text-slate-400">{message.timestamp ? formatDateTime(message.timestamp) : ""}</span>
      </div>
      {isBootstrapContext ? (
        <details
          data-testid="codex-bootstrap-context"
          className="group rounded-xl border border-slate-200/80 bg-white/48 px-3 py-2"
        >
          <summary className="cursor-pointer list-none text-[12px] font-bold text-slate-500">
            <span className="inline-flex items-center gap-2">
              <span className="text-slate-400 group-open:rotate-90">›</span>
              <span>Codex 内置上下文</span>
              <span className="text-[11px] font-semibold text-slate-400">点击展开</span>
            </span>
          </summary>
          <pre className="mt-3 max-h-80 overflow-auto whitespace-pre-wrap break-words font-mono text-[11px] leading-5 text-slate-600">
            {message.text}
          </pre>
        </details>
      ) : (
        <pre
          className={cn(
            "m-0 whitespace-pre-wrap break-words text-[12px] leading-6 text-slate-700",
            isTool ? "font-mono text-[11px] leading-5" : "font-sans",
          )}
        >
          {message.text}
        </pre>
      )}
    </article>
  );
}

function MetaLine({ label, value, monospace = false }: { label: string; value: string; monospace?: boolean }) {
  return (
    <div className="flex min-w-0 items-center gap-2">
      <span className="shrink-0 font-semibold text-slate-400">{label}</span>
      <span className={cn("truncate font-semibold text-slate-700", monospace ? "font-mono" : "")}>{value}</span>
    </div>
  );
}

function projectName(path: string) {
  const normalized = path.replace(/^\\\\\?\\UNC\\/, "\\\\").replace(/^\\\\\?\\/, "");
  const parts = normalized.split(/[\\/]/).filter(Boolean);
  return parts[parts.length - 1] || normalized;
}

function roleName(role: string) {
  if (role === "user") {
    return "用户";
  }
  if (role === "assistant") {
    return "助手";
  }
  if (role === "tool") {
    return "工具";
  }
  return role;
}

function isCodexBootstrapContext(text: string) {
  const trimmed = text.trimStart();
  return [
    "<permissions instructions>",
    "<environment_context>",
    "<collaboration_mode>",
    "<personality_spec>",
    "<skills_instructions>",
    "<plugins_instructions>",
    "# AGENTS.md instructions",
  ].some((prefix) => trimmed.startsWith(prefix));
}

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}
