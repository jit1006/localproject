# Foreign-key relationships

37 tables and 82 foreign-key relationships extracted from SQL.

| Referencing table | Columns | Referenced table | Columns | Nullable reference | Child multiplicity |
|---|---|---|---|---|---|
| department | entity_id | business_entity | entity_id | No | Many |
| warehouse | vendor_id | vendor | vendor_id | No | Many |
| app_user | entity_id | business_entity | entity_id | Yes | Many |
| app_user | vendor_id | vendor | vendor_id | Yes | Many |
| app_user | entity_id, department_id | department | entity_id, department_id | Yes | Many |
| user_session | user_id | app_user | user_id | No | Many |
| retention_policy | entity_id | business_entity | entity_id | Yes | Many |
| retention_policy | document_type | document_type | document_type | No | Many |
| retention_policy | archival_policy | archival_policy | archival_policy | No | Many |
| vendor_rate | vendor_id | vendor | vendor_id | No | Many |
| sla_rule | vendor_id | vendor | vendor_id | Yes | Many |
| event_type | resulting_status | carton_status | status_code | Yes | Many |
| lifecycle_transition | from_status | carton_status | status_code | No | Many |
| lifecycle_transition | event_type | event_type | event_type | No | Many |
| lifecycle_transition | to_status | carton_status | status_code | No | Many |
| import_batch | vendor_id | vendor | vendor_id | Yes | Many |
| import_batch | uploaded_by | app_user | user_id | Yes | Many |
| import_row | batch_id | import_batch | batch_id | No | Many |
| import_issue | row_id | import_row | row_id | No | Many |
| carton | owner_user_id | app_user | user_id | No | Many |
| carton | document_type | document_type | document_type | No | Many |
| carton | archival_policy | archival_policy | archival_policy | No | Many |
| carton | assigned_vendor_id | vendor | vendor_id | No | Many |
| carton | source_row_id | import_row | row_id | Yes | At most one |
| carton | entity_id, department_id | department | entity_id, department_id | No | Many |
| file_record | source_row_id | import_row | row_id | Yes | At most one |
| file_record | carton_id, document_type | carton | carton_id, document_type | No | Many |
| service_request | carton_id | carton | carton_id | No | Many |
| service_request | vendor_id | vendor | vendor_id | No | Many |
| service_request | raised_by | app_user | user_id | No | Many |
| service_request | approved_by | app_user | user_id | Yes | Many |
| service_request | sla_rule_id | sla_rule | sla_rule_id | Yes | Many |
| service_request | source_row_id | import_row | row_id | Yes | At most one |
| event_log | carton_id | carton | carton_id | Yes | Many |
| event_log | event_type | event_type | event_type | No | Many |
| event_log | actor_user_id | app_user | user_id | Yes | Many |
| event_log | source_row_id | import_row | row_id | Yes | Many |
| event_log | resulting_status | carton_status | status_code | Yes | Many |
| event_log | corrects_event_id | event_log | event_id | Yes | Many |
| event_log | carton_id, request_id | service_request | carton_id, request_id | Yes | Many |
| carton_state | carton_id | carton | carton_id | No | At most one |
| carton_state | status_code | carton_status | status_code | No | Many |
| carton_state | vendor_id | vendor | vendor_id | Yes | Many |
| carton_state | carton_id, last_event_id | event_log | carton_id, event_id | No | At most one |
| carton_state | vendor_id, warehouse_id | warehouse | vendor_id, location_id | Yes | Many |
| custody_interval | carton_id | carton | carton_id | No | Many |
| custody_interval | vendor_id | vendor | vendor_id | Yes | Many |
| custody_interval | carton_id, start_event_id | event_log | carton_id, event_id | No | Many |
| custody_interval | carton_id, end_event_id | event_log | carton_id, event_id | Yes | Many |
| custody_interval | vendor_id, warehouse_id | warehouse | vendor_id, location_id | Yes | Many |
| legal_hold | carton_id | carton | carton_id | No | Many |
| legal_hold | raised_by | app_user | user_id | Yes | Many |
| legal_hold | released_by | app_user | user_id | Yes | Many |
| legal_hold | source_row_id | import_row | row_id | Yes | At most one |
| legal_hold | carton_id, applied_event_id | event_log | carton_id, event_id | No | Many |
| legal_hold | carton_id, released_event_id | event_log | carton_id, event_id | Yes | Many |
| vendor_declaration | batch_id | import_batch | batch_id | No | Many |
| vendor_declaration | vendor_id | vendor | vendor_id | No | Many |
| vendor_declaration_item | declaration_id | vendor_declaration | declaration_id | No | Many |
| vendor_declaration_item | source_row_id | import_row | row_id | No | At most one |
| vendor_invoice | vendor_id | vendor | vendor_id | No | Many |
| vendor_invoice | source_row_id | import_row | row_id | No | At most one |
| vendor_invoice_line | invoice_record_id | vendor_invoice | invoice_record_id | Yes | Many |
| vendor_invoice_line | source_row_id | import_row | row_id | No | At most one |
| certificate_evidence | source_row_id | import_row | row_id | Yes | At most one |
| certificate_evidence | evidence_event_id | event_log | event_id | Yes | Many |
| reconciliation_run | requested_by | app_user | user_id | No | Many |
| expected_charge | run_id | reconciliation_run | run_id | No | Many |
| expected_charge | carton_id | carton | carton_id | No | Many |
| expected_charge | vendor_id | vendor | vendor_id | No | Many |
| expected_charge | department_id | department | department_id | No | Many |
| expected_charge | request_id | service_request | request_id | Yes | Many |
| expected_charge | source_event_id | event_log | event_id | Yes | Many |
| expected_charge | rate_id | vendor_rate | rate_id | Yes | Many |
| exception_case | owner_user_id | app_user | user_id | Yes | Many |
| exception_case | owner_vendor_id | vendor | vendor_id | Yes | Many |
| exception_case | carton_id | carton | carton_id | Yes | Many |
| exception_case | resolved_by | app_user | user_id | Yes | Many |
| reconciliation_finding | run_id | reconciliation_run | run_id | No | Many |
| reconciliation_finding | exception_id | exception_case | exception_id | No | Many |
| alert | carton_id | carton | carton_id | No | Many |
| alert | owner_user_id | app_user | user_id | Yes | Many |
