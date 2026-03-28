import { FitAddon } from "@xterm/addon-fit";
import { Terminal } from "@xterm/xterm";
import { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";
import "@xterm/xterm/css/xterm.css";

interface AgentMessage {
  id: number;
  from_module: string;
  to_module: string;
  msg_type: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  resolution: string | null;
}

interface IssueReport {
  id: number;
  issue_type: string;
  module: string;
  description: string;
  status: string;
  created_at: string;
}

interface TmuxSession {
  name: string;
  created: number;
  activity: number;
  cwd: string;
  dead: boolean;
  status: string;
}

const MCP_URL = "http://localhost:3100";

const statusColors: Record<string, string> = {
  new: "bg-blue-100 text-blue-700",
  acknowledged: "bg-amber-100 text-amber-700",
  resolved: "bg-green-100 text-green-700",
};

const priorityColors: Record<string, string> = {
  high: "text-red-600 font-semibold",
  normal: "text-muted-foreground",
};

export function Admin() {
  return (
    <div className="h-full overflow-auto bg-muted/30">
      <div className="max-w-[1400px] mx-auto p-6 flex flex-col gap-6">
        <h1 className="text-xl font-bold">Admin Console</h1>
        <TeamPanel />
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <MessagesPanel />
          <IssuesPanel />
        </div>
      </div>
    </div>
  );
}

function MessagesPanel() {
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [filter, setFilter] = useState<string>("all");

  useEffect(() => {
    async function load() {
      const { data } = await supabase
        .schema("workbench")
        .from("agent_message")
        .select("id, from_module, to_module, msg_type, subject, status, priority, created_at, resolution")
        .order("id", { ascending: false })
        .limit(50);
      if (data) setMessages(data);
    }
    load();
    const channel = supabase
      .channel("admin-messages")
      .on("postgres_changes", { event: "*", schema: "workbench", table: "agent_message" }, () => {
        load();
      })
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const filtered = filter === "all" ? messages : messages.filter((m) => m.status === filter);

  return (
    <section className="bg-card border rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b flex items-center justify-between">
        <h2 className="font-semibold text-sm">Messages ({messages.length})</h2>
        <div className="flex gap-1">
          {["all", "new", "acknowledged", "resolved"].map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              className={`px-2 py-0.5 text-xs rounded-md transition-colors ${filter === s ? "bg-primary text-primary-foreground" : "hover:bg-accent"}`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>
      <div className="max-h-[400px] overflow-auto">
        <table className="w-full text-xs">
          <thead className="sticky top-0 bg-card border-b">
            <tr className="text-left text-muted-foreground">
              <th className="px-3 py-2 w-8">#</th>
              <th className="px-3 py-2">From → To</th>
              <th className="px-3 py-2">Subject</th>
              <th className="px-3 py-2 w-20">Status</th>
              <th className="px-3 py-2 w-16">Pri</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => (
              <tr key={m.id} className="border-b hover:bg-accent/50 transition-colors">
                <td className="px-3 py-2 text-muted-foreground">{m.id}</td>
                <td className="px-3 py-2 font-mono">
                  {m.from_module} → {m.to_module}
                </td>
                <td className="px-3 py-2 truncate max-w-[250px]" title={m.subject}>
                  {m.subject}
                </td>
                <td className="px-3 py-2">
                  <span className={`px-1.5 py-0.5 rounded text-[10px] ${statusColors[m.status] ?? ""}`}>
                    {m.status}
                  </span>
                </td>
                <td className={`px-3 py-2 ${priorityColors[m.priority] ?? ""}`}>{m.priority}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function IssuesPanel() {
  const [issues, setIssues] = useState<IssueReport[]>([]);

  useEffect(() => {
    async function load() {
      const { data } = await supabase
        .schema("workbench")
        .from("issue_report")
        .select("id, issue_type, module, description, status, created_at")
        .order("id", { ascending: false })
        .limit(50);
      if (data) setIssues(data);
    }
    load();
    const channel = supabase
      .channel("admin-issues")
      .on("postgres_changes", { event: "*", schema: "workbench", table: "issue_report" }, () => {
        load();
      })
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return (
    <section className="bg-card border rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b">
        <h2 className="font-semibold text-sm">Issues ({issues.length})</h2>
      </div>
      <div className="max-h-[400px] overflow-auto">
        <table className="w-full text-xs">
          <thead className="sticky top-0 bg-card border-b">
            <tr className="text-left text-muted-foreground">
              <th className="px-3 py-2 w-8">#</th>
              <th className="px-3 py-2">Module</th>
              <th className="px-3 py-2">Description</th>
              <th className="px-3 py-2 w-20">Status</th>
            </tr>
          </thead>
          <tbody>
            {issues.map((issue) => (
              <tr key={issue.id} className="border-b hover:bg-accent/50 transition-colors">
                <td className="px-3 py-2 text-muted-foreground">{issue.id}</td>
                <td className="px-3 py-2 font-mono">{issue.module}</td>
                <td className="px-3 py-2 truncate max-w-[250px]" title={issue.description}>
                  {issue.description}
                </td>
                <td className="px-3 py-2">
                  <span className={`px-1.5 py-0.5 rounded text-[10px] ${statusColors[issue.status] ?? ""}`}>
                    {issue.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function timeAgo(ts: number): string {
  const diff = Math.floor((Date.now() - ts) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function TeamPanel() {
  const [sessions, setSessions] = useState<TmuxSession[]>([]);
  const [active, setActive] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const res = await fetch(`${MCP_URL}/api/tmux`);
        if (res.ok) {
          const data = await res.json();
          setSessions(data);
        }
      } catch {}
    }
    load();
    const interval = setInterval(load, 10_000);
    return () => clearInterval(interval);
  }, []);

  return (
    <section className="bg-card border rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b">
        <h2 className="font-semibold text-sm">Team ({sessions.length} members)</h2>
      </div>
      <div className="divide-y">
        {sessions.map((s) => (
          <div key={s.name}>
            <button
              onClick={() => setActive(active === s.name ? null : s.name)}
              className="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-accent/50 transition-colors"
            >
              <span className={`w-2 h-2 rounded-full shrink-0 ${s.dead ? "bg-red-500" : "bg-green-500"}`} />
              <span className="text-sm font-medium w-20">{s.name}</span>
              <span className="text-xs text-muted-foreground truncate flex-1">{s.status}</span>
              <span className="text-[10px] text-muted-foreground shrink-0">{timeAgo(s.activity)}</span>
              <span className={`text-xs transition-transform ${active === s.name ? "rotate-180" : ""}`}>▾</span>
            </button>
            {active === s.name && (
              <div className="h-[400px] bg-black">
                <TerminalView key={s.name} session={s.name} />
              </div>
            )}
          </div>
        ))}
        {sessions.length === 0 && (
          <div className="px-4 py-6 text-xs text-muted-foreground text-center">No active sessions</div>
        )}
      </div>
    </section>
  );
}

function TerminalView({ session }: { session: string }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const term = new Terminal({
      fontSize: 12,
      fontFamily: "'GeistMono', 'SF Mono', 'Menlo', monospace",
      theme: {
        background: "#0a0a0a",
        foreground: "#e5e5e5",
        cursor: "#e5e5e5",
        selectionBackground: "#ffffff40",
      },
      cursorBlink: false,
      disableStdin: true,
      scrollback: 5000,
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(containerRef.current);

    // Fit after mount
    requestAnimationFrame(() => fit.fit());

    const wsUrl = `ws://localhost:3100/ws/tmux/${session}`;
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      // Send initial resize
      const { cols, rows } = term;
      ws.send(JSON.stringify({ type: "resize", cols, rows }));
    };

    ws.onmessage = (e) => {
      term.write(e.data);
    };

    ws.onclose = () => {
      term.write("\r\n\x1b[33m[disconnected]\x1b[0m\r\n");
    };

    // Resize observer
    const ro = new ResizeObserver(() => {
      fit.fit();
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "resize", cols: term.cols, rows: term.rows }));
      }
    });
    ro.observe(containerRef.current);

    termRef.current = term;

    return () => {
      ro.disconnect();
      ws.close();
      term.dispose();
    };
  }, [session]);

  return <div ref={containerRef} className="h-full w-full" />;
}
