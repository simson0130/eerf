// =============================================================================
// EERF Portal Type Definitions
// =============================================================================

export interface Service {
  service_key: string;
  fqdn: string;
  account_id: string;
  account_name?: string;
  environment?: string;
  governance: string;
  operation: string;
  health: string;
  config: string;
  readiness?: {
    role: boolean;
    waf: boolean;
    sg: boolean;
    alb: boolean;
    recommendation: string;
    score?: number;
  };
}

export interface DashboardSummary {
  total: number;
  approved: number;
  protected: number;
  pending: number;
  excluded: number;
  failover: number;
  unhealthy: number;
  coverage: number;
  mttd_avg: number;
  mttr_avg: number;
  drill_mttd_avg: number;
  drill_mttr_avg: number;
  recent_incidents: { service_key: string; action: string; outcome: string; timestamp: string; source: string }[];
}

export interface HistoryEntry {
  PK: string;
  SK: string;
  axis: string;
  previous_state: string;
  new_state: string;
  operator_id?: string;
  reason?: string;
  changed_at: string;
  service_key?: string;
}

export interface Execution {
  type: string;
  status: string;
  startDate: string;
  stopDate?: string;
  service_key: string;
  executionArn?: string;
  name?: string;
}

export interface Alarm {
  name: string;
  state: string;
  updated: string;
}

export interface Account {
  account_id: string;
  account_name?: string;
  environment?: string;
  scan_status: string;
  services_count: number;
  scan_error?: string;
}

export interface EvidenceRecord {
  service_key: string;
  action: string;
  source: string;  // alarm | drill | operator
  outcome: string;
  timestamp: string;
  trigger_time: string;
  mttr_seconds: number;
  mttd_seconds?: number;
  execution_arn?: string;
  validation_status?: string;
  before_state?: { dns_target?: string; waf_mode?: string; emergency_sg_attached?: boolean; security_groups?: string[] };
  after_state?: { dns_target?: string; waf_mode?: string; emergency_sg_attached?: boolean };
  affected_resources?: string[];
  correlation_id?: string;
}

export interface User {
  email: string;
  username?: string;
  status: string;
  enabled?: boolean;
  group: string;
  groups?: string[];
  created: string;
}
