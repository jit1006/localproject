-- Synthetic isolated constraint tests; run after 01_schema.sql + 02_seed_reference.sql.
-- Every fixture is rolled back. These are NOT supplied operational demo data.
BEGIN;
SET search_path = prms, public;
CREATE FUNCTION pg_temp.expect_error(stmt text, expected_state text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE caught text;
BEGIN
  BEGIN
    EXECUTE stmt;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS caught = RETURNED_SQLSTATE;
    IF caught <> expected_state THEN
      RAISE EXCEPTION 'Expected SQLSTATE %, got % for %', expected_state, caught, stmt;
    END IF;
    RETURN;
  END;
  RAISE EXCEPTION 'Expected SQLSTATE %, but statement succeeded: %', expected_state, stmt;
END;
$$;
INSERT INTO business_entity VALUES ('TEST-E','Constraint test entity');
INSERT INTO department VALUES ('TEST-D','TEST-E','Constraint test department');
INSERT INTO vendor(vendor_id,vendor_name,status) VALUES ('TEST-V','Constraint test vendor','Active'),('TEST-V2','Other test vendor','Active');
INSERT INTO warehouse VALUES ('TEST-W','TEST-V','Test warehouse','Test city',100);
INSERT INTO app_user(user_id,full_name,email,role_code,entity_id,department_id)
VALUES ('TEST-U','Synthetic tester','test-user@example.invalid','BUSINESS','TEST-E','TEST-D');
SELECT pg_temp.expect_error($q$ INSERT INTO app_user(user_id,full_name,email,role_code)
  VALUES ('TEST-BAD','Bad scope','bad@example.invalid','BUSINESS') $q$, '23514');
INSERT INTO carton(carton_id,entity_id,department_id,owner_user_id,document_type,archival_policy,carton_created_date,retention_trigger_date,assigned_vendor_id)
VALUES ('TEST-C','TEST-E','TEST-D','TEST-U','Client KYC','Standard','2020-01-01','2020-01-01','TEST-V');
SELECT pg_temp.expect_error($q$ INSERT INTO file_record(file_id,carton_id,file_ref,document_type)
 VALUES ('TEST-F','TEST-C','file','Invoices') $q$, '23503');
SELECT pg_temp.expect_error($q$ INSERT INTO service_request(request_id,carton_id,request_type,vendor_id,raised_by,raised_at,request_status,approved_by,approved_at)
 VALUES ('TEST-R','TEST-C','DESTRUCTION','TEST-V','TEST-U','2026-01-01','Open','TEST-U','2026-01-02') $q$, '23514');
INSERT INTO event_log(stream_kind,stream_id,stream_version,carton_id,event_type,occurred_at,actor_user_id,actor_role,channel,resulting_status,idempotency_key)
VALUES ('CARTON','TEST-C',1,'TEST-C','CARTON_CREATED','2020-01-01','TEST-U','BUSINESS','API','Created','TEST-CREATE');
SELECT pg_temp.expect_error($q$ UPDATE event_log SET payload = '{}' WHERE idempotency_key='TEST-CREATE' $q$, '55000');
SELECT pg_temp.expect_error($q$ DELETE FROM event_log WHERE idempotency_key='TEST-CREATE' $q$, '55000');
SELECT pg_temp.expect_error($q$ TRUNCATE TABLE event_log CASCADE $q$, '55000');
SELECT pg_temp.expect_error($q$ INSERT INTO event_log(stream_kind,stream_id,stream_version,carton_id,event_type,occurred_at,actor_role,channel,idempotency_key)
 VALUES ('CARTON','TEST-C',2,'TEST-C','LEGAL_HOLD_APPLIED','2020-02-01','COMPLIANCE','MIGRATION','TEST-CREATE') $q$, '23505');
-- Non-state-changing events legitimately leave resulting_status NULL.
INSERT INTO event_log(stream_kind,stream_id,stream_version,carton_id,event_type,occurred_at,actor_role,channel,idempotency_key)
VALUES ('CARTON','TEST-C',2,'TEST-C','LEGAL_HOLD_APPLIED','2020-02-01','COMPLIANCE','MIGRATION','TEST-HOLD');
INSERT INTO carton_state(carton_id,status_code,custody,state_since,last_event_id,version)
SELECT 'TEST-C','Created','BUSINESS','2020-01-01',event_id,1 FROM event_log WHERE idempotency_key='TEST-CREATE';
SELECT pg_temp.expect_error($q$ UPDATE carton_state SET custody='WAREHOUSE',warehouse_id='TEST-W',vendor_id='TEST-V2' WHERE carton_id='TEST-C' $q$, '23503');
INSERT INTO vendor_rate(vendor_id,activity,rate_inr,unit,effective_from,effective_to)
VALUES ('TEST-V','STORAGE',100,'PER_CARTON_MONTH','2026-01-01','2026-04-01');
-- Adjacent exclusive ranges are valid.
INSERT INTO vendor_rate(vendor_id,activity,rate_inr,unit,effective_from)
VALUES ('TEST-V','STORAGE',108,'PER_CARTON_MONTH','2026-04-01');
SELECT pg_temp.expect_error($q$ INSERT INTO vendor_rate(vendor_id,activity,rate_inr,unit,effective_from,effective_to)
 VALUES ('TEST-V','STORAGE',99,'PER_CARTON_MONTH','2026-03-01','2026-05-01') $q$, '23P01');
INSERT INTO custody_interval(carton_id,custody,valid_from,start_event_id)
SELECT 'TEST-C','BUSINESS','2020-01-01',event_id FROM event_log WHERE idempotency_key='TEST-CREATE';
SELECT pg_temp.expect_error($q$ INSERT INTO custody_interval(carton_id,custody,valid_from,start_event_id)
 SELECT 'TEST-C','TRANSIT','2020-02-01',event_id FROM event_log WHERE idempotency_key='TEST-HOLD' $q$, '23P01');
-- Entity-specific policy overrides global default; view recomputes immediately.
INSERT INTO retention_policy(policy_id,entity_id,document_type,archival_policy,retention_years)
VALUES ('TEST-P','TEST-E','Client KYC','Standard',9);
DO $$ BEGIN
  IF (SELECT destruction_due_on FROM carton_retention WHERE carton_id='TEST-C') <> DATE '2029-01-01' THEN
    RAISE EXCEPTION 'Scoped retention override failed';
  END IF;
END $$;
UPDATE retention_policy SET retention_years=10,revision=2 WHERE policy_id='TEST-P';
DO $$ BEGIN
  IF (SELECT destruction_due_on FROM carton_retention WHERE carton_id='TEST-C') <> DATE '2030-01-01' THEN
    RAISE EXCEPTION 'Retention recomputation failed';
  END IF;
END $$;
UPDATE carton SET retention_trigger_date=NULL WHERE carton_id='TEST-C';
DO $$ BEGIN
  IF (SELECT calculation_status FROM carton_retention WHERE carton_id='TEST-C') <> 'MISSING_TRIGGER' THEN
    RAISE EXCEPTION 'Missing trigger was hidden';
  END IF;
END $$;
-- Same certificate across cartons is allowed; even conflicting evidence remains detectable.
INSERT INTO certificate_evidence(certificate_reference,carton_reference,vendor_reference,destroyed_on,evidence_event_id)
SELECT 'TEST-CERT','UNKNOWN-1','TEST-V','2026-01-01',event_id FROM event_log WHERE idempotency_key='TEST-CREATE';
INSERT INTO certificate_evidence(certificate_reference,carton_reference,vendor_reference,destroyed_on,evidence_event_id)
SELECT 'TEST-CERT','UNKNOWN-2','TEST-V2','2026-02-01',event_id FROM event_log WHERE idempotency_key='TEST-CREATE';
SELECT 'Constraint checks passed; all synthetic fixtures rolled back next.' AS result;
ROLLBACK;
