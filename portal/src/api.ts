import { config } from "./config";
import type { Service, DashboardSummary, HistoryEntry, Execution, Alarm, Account, EvidenceRecord, User } from "./types";

const API = config.apiUrl;
let isRedirecting = false;

function getToken(): string | null {
  return localStorage.getItem("eerf_token");
}

function isTokenExpired(): boolean {
  const token = getToken();
  if (!token) return true;
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    return payload.exp * 1000 < Date.now();
  } catch {
    return true;
  }
}

function forceLogout() {
  if (isRedirecting) return;
  isRedirecting = true;
  localStorage.removeItem("eerf_token");
  localStorage.setItem("eerf_session_expired", "true");
  window.location.href = "/login";
}

// Token expiry check (5min interval)
if (typeof window !== "undefined") {
  setInterval(() => {
    if (getToken() && isTokenExpired()) {
      forceLogout();
    }
  }, config.sessionWarningMs);
}

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function apiFetch<T = any>(path: string, options: RequestInit = {}): Promise<T> {
  if (isTokenExpired()) {
    forceLogout();
    throw new ApiError("Token expired", 401);
  }

  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };

  const res = await fetch(`${API}${path}`, { ...options, headers });

  if (res.status === 401) {
    forceLogout();
    throw new ApiError("Unauthorized", 401);
  }

  if (!res.ok) {
    const body = await res.text();
    throw new ApiError(body || `API Error: ${res.status}`, res.status);
  }

  return res.json();
}

// --- Services ---
export async function getServices(): Promise<{ services: Service[] }> {
  return apiFetch("/services");
}

export async function getService(key: string) {
  return apiFetch(`/services/${key}`);
}

export async function getHistory(key: string, limit = 20): Promise<{ history: HistoryEntry[] }> {
  return apiFetch(`/services/${key}/history?limit=${limit}`);
}

export async function getAllHistory(days = 3, axis?: string, serviceKey?: string): Promise<{ history: HistoryEntry[]; count?: number }> {
  let url = `/history?days=${days}`;
  if (axis) url += `&axis=${axis}`;
  if (serviceKey) url += `&service_key=${serviceKey}`;
  return apiFetch(url);
}

export async function searchService(fqdn: string) {
  return apiFetch(`/services/search?fqdn=${encodeURIComponent(fqdn)}`);
}

// --- Governance ---
export async function changeGovernance(key: string, action: string, reason: string) {
  return apiFetch(`/services/${key}/governance`, {
    method: "POST",
    body: JSON.stringify({ action, reason }),
  });
}

// --- Executions ---
export async function getExecutions(key: string, limit = 10): Promise<{ executions: Execution[] }> {
  return apiFetch(`/services/${key}/executions?limit=${limit}`);
}

export async function getAlarms(key: string): Promise<{ alarms: Alarm[] }> {
  return apiFetch(`/services/${key}/alarms`);
}

export async function getWafRules(key: string): Promise<{ rules: Array<{ name: string; mode: string; excluded: boolean; priority: number }>; web_acl_name?: string }> {
  return apiFetch(`/services/${key}/waf-rules`);
}

// --- Failback ---
export async function triggerFailback(key: string, reason: string) {
  return apiFetch(`/services/${key}/failback`, {
    method: "POST",
    body: JSON.stringify({ reason }),
  });
}

// --- Accounts ---
export async function getAccounts(): Promise<{ accounts: Account[] }> {
  return apiFetch("/accounts");
}

// --- Dashboard ---
export async function getDashboardSummary(): Promise<DashboardSummary> {
  return apiFetch("/dashboard/summary");
}

// --- Reports ---
export async function getReport(type = "operational") {
  return apiFetch(`/reports?type=${type}`);
}

// --- Running / Recent Executions ---
export async function getRunningExecutions(): Promise<{ running: Execution[] }> {
  return apiFetch("/executions/running");
}

export async function getRecentExecutions(limit = 30): Promise<{ executions: Execution[] }> {
  return apiFetch(`/executions/recent?limit=${limit}`);
}

// --- Discovery ---
export async function triggerDiscovery() {
  return apiFetch("/discovery/run", { method: "POST" });
}

// --- Evaluate ---
export async function triggerEvaluate(serviceKey?: string) {
  return apiFetch("/evaluate/run", {
    method: "POST",
    body: JSON.stringify(serviceKey ? { service_key: serviceKey } : {}),
  });
}

// --- Infrastructure (Cross-Account) ---
export async function getAccountAlbs(accountId: string) {
  return apiFetch(`/accounts/${accountId}/albs`);
}

export async function getAccountWafs(accountId: string) {
  return apiFetch(`/accounts/${accountId}/wafs`);
}

export async function getAccountSgs(accountId: string) {
  return apiFetch(`/accounts/${accountId}/sgs`);
}

export async function associateWaf(accountId: string, webAclArn: string, albArn: string) {
  return apiFetch(`/accounts/${accountId}/waf-associate`, {
    method: "POST",
    body: JSON.stringify({ web_acl_arn: webAclArn, alb_arn: albArn }),
  });
}

export async function createEmergencySg(accountId: string, vpcId: string) {
  return apiFetch(`/accounts/${accountId}/create-sg`, {
    method: "POST",
    body: JSON.stringify({ vpc_id: vpcId }),
  });
}

// --- Failover Test ---
export async function testBreak(serviceKey: string) {
  return apiFetch("/test/break", {
    method: "POST",
    body: JSON.stringify({ service_key: serviceKey }),
  });
}

export async function testRestore(serviceKey: string, originalOrigin: string) {
  return apiFetch("/test/restore", {
    method: "POST",
    body: JSON.stringify({ service_key: serviceKey, original_origin: originalOrigin }),
  });
}

export async function getTestStatus(serviceKey: string) {
  return apiFetch(`/test/status/${serviceKey}`);
}

// --- Users ---
export async function getUsers(): Promise<{ users: User[] }> {
  return apiFetch("/users");
}

export async function inviteUser(email: string, group: string) {
  return apiFetch("/users", {
    method: "POST",
    body: JSON.stringify({ email, group }),
  });
}

export async function updateUserGroup(email: string, group: string) {
  return apiFetch("/users/group", {
    method: "PUT",
    body: JSON.stringify({ email, group }),
  });
}

export async function deleteUser(email: string) {
  return apiFetch("/users", {
    method: "DELETE",
    body: JSON.stringify({ email }),
  });
}

// --- Evidence ---
export async function getEvidence(serviceKey?: string, limit = 20): Promise<{ evidence: EvidenceRecord[]; stats?: any }> {
  let url = "/evidence";
  const params: string[] = [];
  if (serviceKey) params.push(`service_key=${serviceKey}`);
  if (limit) params.push(`limit=${limit}`);
  if (params.length) url += `?${params.join("&")}`;
  return apiFetch(url);
}

// --- Service Metadata ---
export async function updateServiceMetadata(serviceKey: string, metadata: Record<string, any>) {
  return apiFetch(`/services/${serviceKey}/metadata`, {
    method: "PUT",
    body: JSON.stringify(metadata),
  });
}

export async function updateWafExcludeRules(serviceKey: string, rules: string[]) {
  return apiFetch(`/services/${serviceKey}/metadata`, {
    method: "PUT",
    body: JSON.stringify({ waf_exclude_rules: rules }),
  });
}

// --- Governance Pipeline Executions ---
export async function getGovernanceExecutions(limit = 10): Promise<{ executions: any[] }> {
  return apiFetch(`/governance/executions?limit=${limit}`);
}

// --- Policy Management ---
export interface PolicyRules {
  kill_switch: boolean;
  max_concurrent_failover: number;
  correlated_failure_threshold: number;
  criticality_rules: Record<string, Record<string, string>>;
  maintenance_windows: Array<{ day: string; start: string; end: string; action: string }>;
  default_business_hours: string;
}

export async function getPolicyRules(): Promise<{ rules: PolicyRules; source: string }> {
  return apiFetch("/policy/rules");
}

export async function updatePolicyRules(rules: PolicyRules) {
  return apiFetch("/policy/rules", {
    method: "PUT",
    body: JSON.stringify({ rules }),
  });
}

export async function getPolicyOverride(serviceKey: string) {
  return apiFetch(`/policy/override/${serviceKey}`);
}

export async function updatePolicyOverride(serviceKey: string, override: Record<string, any>) {
  return apiFetch(`/policy/override/${serviceKey}`, {
    method: "PUT",
    body: JSON.stringify({ override }),
  });
}

export async function evaluatePolicyDryRun(serviceKey: string) {
  return apiFetch("/policy/evaluate", {
    method: "POST",
    body: JSON.stringify({ service_key: serviceKey }),
  });
}
