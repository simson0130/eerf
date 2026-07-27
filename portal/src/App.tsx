import { BrowserRouter, Routes, Route, Link, useLocation } from "react-router-dom";
import { Component, type ErrorInfo, type ReactNode, useState, useEffect } from "react";
import { ToastProvider } from "./components/Toast";
import { useAuth } from "./hooks/useAuth";
import { config } from "./config";
import Evaluate from "./pages/Evaluate";
import Dashboard from "./pages/Dashboard";
import ServiceDetail from "./pages/ServiceDetail";
import Services from "./pages/Services";
import Incidents from "./pages/Incidents";
import StatusView from "./pages/StatusView";
import ReportsView from "./pages/Reports";
import Discovery from "./pages/Discovery";
import Failback from "./pages/Failback";
import FailoverTest from "./pages/FailoverTest";
import GovernanceChange from "./pages/GovernanceChange";
import Onboarding from "./pages/Onboarding";
import Infrastructure from "./pages/Infrastructure";
import Settings from "./pages/Settings";
import ServiceSettings from "./pages/ServiceSettings";
import ExcludedServices from "./pages/ExcludedServices";
import PolicySettings from "./pages/PolicySettings";
import Login from "./pages/Login";

class ErrorBoundary extends Component<{ children: ReactNode }, { hasError: boolean; error?: Error }> {
  state = { hasError: false, error: undefined as Error | undefined };
  static getDerivedStateFromError(error: Error) { return { hasError: true, error }; }
  componentDidCatch(error: Error, info: ErrorInfo) { console.error("Page error:", error, info); }
  render() {
    if (this.state.hasError) {
      return (
        <div className="flex flex-col items-center justify-center h-64 gap-3">
          <span className="text-3xl">💥</span>
          <p className="text-gray-600">\ud398\uc774\uc9c0 \ub85c\ub4dc \uc911 \uc624\ub958 \ubc1c\uc0dd</p>
          <button onClick={() => { this.setState({ hasError: false }); window.location.reload(); }}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm">\uc0c8\ub85c\uace0\uce68</button>
        </div>
      );
    }
    return this.props.children;
  }
}

const menuGroups = [
  { label: "\uc6b4\uc601 \ud604\ud669", items: [
    { path: "/", label: "\ub300\uc2dc\ubcf4\ub4dc", icon: "\ud83d\udcca" },
    { path: "/services", label: "\ubcf4\ud638 \uc11c\ube44\uc2a4 \uc0c1\uc138", icon: "\ud83d\udda5\ufe0f" },
    { path: "/incidents", label: "\uc778\uc2dc\ub358\ud2b8 \uad00\ub9ac", icon: "\ud83d\udea8" },
    { path: "/status", label: "\ubcc0\uacbd \uc774\ub825 \uad00\ub9ac", icon: "\ud83d\udccb" },
    { path: "/reports", label: "\ubcf4\uace0\uc11c", icon: "\ud83d\udcc4" },
  ]},
  { label: "\ubcf4\ud638 \uccb4\uacc4", items: [
    { path: "/discovery", label: "\ub300\uc0c1 \ud0d0\uc0c9", icon: "\ud83d\udd0d" },
    { path: "/evaluate", label: "\uc900\ube44\ub3c4 \ud3c9\uac00", icon: "\ud83d\udcd0" },
    { path: "/governance", label: "\ubcf4\ud638 \uc2b9\uc778", icon: "\u2705" },
    { path: "/onboarding", label: "\ubcf4\ud638 \ub4f1\ub85d", icon: "\ud83d\udcdd" },
  ]},
  { label: "\ubcf5\uad6c \uc6b4\uc601", items: [
    { path: "/failback", label: "\ubcf5\uc6d0 \uc2e4\ud589", icon: "\u26a1" },
    { path: "/failover-test", label: "\ubcf5\uad6c \ub9ac\ud5c8\uc124", icon: "\ud83e\uddea" },
    { path: "/infrastructure", label: "\uc778\ud504\ub77c \ubcc0\uacbd", icon: "\ud83d\udd27" },
  ]},
  { label: "\uc124\uc815", items: [
    { path: "/settings", label: "\uc0ac\uc6a9\uc790 \uad00\ub9ac", icon: "\u2699\ufe0f" },
    { path: "/service-settings", label: "\uc11c\ube44\uc2a4 \uc124\uc815", icon: "\ud83d\udccb" },
    { path: "/policy-settings", label: "\ubcf5\uad6c \uc815\ucc45", icon: "\ud83d\udee1\ufe0f" },
    { path: "/excluded", label: "\uc608\uc678 \uc11c\ube44\uc2a4", icon: "\ud83d\udeab" },
  ]},
];

function Sidebar() {
  const location = useLocation();
  const { isAdmin, isOperator } = useAuth();
  const [openGroups, setOpenGroups] = useState<Set<string>>(new Set(menuGroups.map(g => g.label)));
  const toggleGroup = (label: string) => {
    setOpenGroups(prev => { const next = new Set(prev); if (next.has(label)) next.delete(label); else next.add(label); return next; });
  };
  const filteredGroups = menuGroups.filter(g => {
    if (g.label === "\uc124\uc815" && !isAdmin) return false;
    if (g.label === "\ubcf4\ud638 \uccb4\uacc4" && !isAdmin) return false;
    if (g.label === "\ubcf5\uad6c \uc6b4\uc601" && !isOperator) return false;
    return true;
  });
  return (
    <aside className="w-56 bg-gray-900 text-gray-300 min-h-screen flex flex-col">
      <div className="p-4 border-b border-gray-700">
        <Link to="/" className="text-lg font-bold text-white flex items-center gap-2">\ud83d\udee1\ufe0f EERF Portal</Link>
        <p className="text-xs text-gray-500 mt-1">Edge Recovery Management</p>
      </div>
      <nav className="flex-1 py-2 overflow-y-auto">
        {filteredGroups.map(group => (
          <div key={group.label} className="mb-0.5">
            <button onClick={() => toggleGroup(group.label)} className="w-full flex items-center justify-between px-4 py-2 text-[9px] font-bold text-gray-500 uppercase tracking-widest hover:text-gray-300">
              <span>{group.label}</span><span className={`text-[8px] transition-transform ${openGroups.has(group.label) ? "rotate-90" : ""}`}>\u25b6</span>
            </button>
            {openGroups.has(group.label) && group.items.map(item => {
              const active = location.pathname === item.path || (item.path !== "/" && location.pathname.startsWith(item.path));
              return <Link key={item.path} to={item.path} className={`flex items-center gap-3 px-4 py-2 text-sm transition-colors ${active ? "bg-gray-800 text-white border-l-2 border-blue-400" : "hover:bg-gray-800 hover:text-white border-l-2 border-transparent"}`}><span className="text-xs">{item.icon}</span><span>{item.label}</span></Link>;
            })}
          </div>
        ))}
      </nav>
      <div className="p-4 border-t border-gray-700 text-xs text-gray-500">
        <button onClick={() => { localStorage.removeItem("eerf_token"); window.location.href = "/login"; }} className="hover:text-white">\ud83d\udeaa \ub85c\uadf8\uc544\uc6c3</button>
      </div>
    </aside>
  );
}

function Layout({ children }: { children: React.ReactNode }) {
  return (<div className="flex min-h-screen bg-gray-50"><Sidebar /><main className="flex-1 p-6 overflow-auto"><ErrorBoundary>{children}</ErrorBoundary></main></div>);
}

export default function App() {
  const token = localStorage.getItem("eerf_token");
  if (!token && window.location.pathname !== "/login") { window.location.href = "/login"; return null; }
  if (window.location.pathname === "/login") return <BrowserRouter><Routes><Route path="/login" element={<Login />} /></Routes></BrowserRouter>;
  return (
    <BrowserRouter><ToastProvider><Layout><Routes>
      <Route path="/" element={<Dashboard />} />
      <Route path="/services" element={<Services />} />
      <Route path="/services/:key" element={<ServiceDetail />} />
      <Route path="/incidents" element={<Incidents />} />
      <Route path="/status" element={<StatusView />} />
      <Route path="/reports" element={<ReportsView />} />
      <Route path="/onboarding" element={<Onboarding />} />
      <Route path="/evaluate" element={<Evaluate />} />
      <Route path="/infrastructure" element={<Infrastructure />} />
      <Route path="/discovery" element={<Discovery />} />
      <Route path="/governance" element={<GovernanceChange />} />
      <Route path="/failback" element={<Failback />} />
      <Route path="/failover-test" element={<FailoverTest />} />
      <Route path="/settings" element={<Settings />} />
      <Route path="/service-settings" element={<ServiceSettings />} />
      <Route path="/excluded" element={<ExcludedServices />} />
      <Route path="/policy-settings" element={<PolicySettings />} />
      <Route path="/login" element={<Login />} />
    </Routes></Layout></ToastProvider></BrowserRouter>
  );
}
