-- psql-only template. First provision a NON-OWNER, NON-SUPERUSER runtime login.
-- Supply its existing name: psql ... -v runtime_role=prms_app -f 03_runtime_grants.sql
-- Passwords are provisioned outside this file. Do NOT grant the migration owner.
-- Backend services enforce end-user role/row/field permissions; no end user gets SQL access.
BEGIN;
GRANT USAGE ON SCHEMA prms TO :"runtime_role";
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA prms TO :"runtime_role";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA prms TO :"runtime_role";
GRANT UPDATE ON prms.app_user, prms.user_session,
  prms.business_entity, prms.department, prms.vendor, prms.warehouse,
  prms.document_type, prms.archival_policy, prms.retention_policy,
  prms.vendor_rate, prms.sla_rule, prms.holiday, prms.threshold_rule, prms.tax_rule,
  prms.carton, prms.file_record, prms.service_request, prms.carton_state,
  prms.custody_interval, prms.legal_hold, prms.reconciliation_run,
  prms.exception_case, prms.alert TO :"runtime_role";
-- No DELETE, TRUNCATE, DDL, ownership or event/evidence UPDATE privileges.
-- Reference changes and projection changes must pass through audited service commands.
-- Maintenance/rebuild is an offline migration-owner operation, never an HTTP endpoint.
COMMIT;
