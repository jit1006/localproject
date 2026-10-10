export type Role = "BUSINESS" | "VENDOR" | "COMPLIANCE" | "FACILITIES";

export interface User {
  user_id: string;
  full_name: string;
  email: string;
  role_code: Role;
  entity_id?: string | null;
  department_id?: string | null;
  vendor_id?: string | null;
}

export interface Carton {
  carton_id: string;
  entity_id: string;
  department_id: string;
  document_type: string;
  archival_policy: string;
  assigned_vendor_id: string;
  retention_trigger_date?: string | null;
  declared_file_count?: number | null;
  barcode?: string | null;
}

export interface ServiceRequest {
  request_id: string;
  carton_id: string;
  request_type: string;
  vendor_id: string;
  request_status: string;
  approved_by?: string | null;
}

export interface DashboardSummary {
  role: Role;
  totalCartons: number;
  totalRequests: number;
  cartonsByStatus: { status_code: string; n: number }[];
}

export interface CartonHistory {
  state: Record<string, unknown> | null;
  events: {
    eventId: number;
    eventType: string;
    occurredAt: string | null;
    actorRole: string;
    resultingStatus: string | null;
  }[];
}
