-- Reference seed (SQLite) — derived from the supplied workbook; no operational
-- records or passwords. Apply once after schema.sql. Rate effective_to is EXCLUSIVE.
PRAGMA foreign_keys = ON;

INSERT INTO business_entity (entity_id, entity_name) VALUES
  ('ENT-BRN','Branch Banking'), ('ENT-MF','Mutual Fund'), ('ENT-GCC','GCC');

INSERT INTO department (department_id, entity_id, department_name) VALUES
  ('DEP-BRN-DEL','ENT-BRN','Delhi Branch'),
  ('DEP-BRN-PUN','ENT-BRN','Pune Branch'),
  ('DEP-BRN-MUM','ENT-BRN','Mumbai Branch'),
  ('DEP-BRN-KOL','ENT-BRN','Kolkata Branch'),
  ('DEP-BRN-CHE','ENT-BRN','Chennai Branch'),
  ('DEP-MF-OPS','ENT-MF','MF Operations'),
  ('DEP-MF-INV','ENT-MF','Investor Services'),
  ('DEP-MF-CMP','ENT-MF','MF Compliance'),
  ('DEP-GCC-TRP','ENT-GCC','Transport'),
  ('DEP-GCC-RE','ENT-GCC','Real Estate'),
  ('DEP-GCC-AFMG','ENT-GCC','AFMG'),
  ('DEP-GCC-AP','ENT-GCC','Accounts Payable'),
  ('DEP-GCC-HR','ENT-GCC','Human Resources');

INSERT INTO vendor (vendor_id, vendor_name, status, contract_start, contract_ref, ops_contact_email, recertification_frequency) VALUES
  ('VND-001','SecureVault Storage Pvt Ltd','Active','2018-04-01','MSA-2018-114','vendor.ops@securevault.example','Quarterly'),
  ('VND-002','RecordSafe India Ltd','Active','2020-07-01','MSA-2020-227','india.ops@recordsafe.example','Quarterly'),
  ('VND-003','ArchivePro Logistics','Active','2023-01-15','MSA-2022-091','support@archivepro.example','Quarterly');

INSERT INTO warehouse (location_id, vendor_id, location_name, city, capacity_cartons) VALUES
  ('LOC-MUM-01','VND-001','Mumbai Warehouse - Bhiwandi','Mumbai',22000),
  ('LOC-DEL-01','VND-001','Delhi NCR Warehouse - Manesar','Delhi NCR',14000),
  ('LOC-PUN-01','VND-002','Pune Warehouse - Chakan','Pune',9000),
  ('LOC-KOL-01','VND-002','Kolkata Warehouse - Dankuni','Kolkata',6000),
  ('LOC-CHE-01','VND-003','Chennai Warehouse - Sriperumbudur','Chennai',7000),
  ('LOC-BLR-01','VND-003','Bengaluru Warehouse - Nelamangala','Bengaluru',8000);

INSERT INTO document_type (document_type, base_retention_years, trigger_event_description) VALUES
  ('Client KYC',8,'Relationship closure date'),
  ('Loan Agreements',10,'Loan closure date'),
  ('Other Agreements and Vendor Data',7,'Contract end date'),
  ('Vendor Onboarding',7,'Onboarding completion date'),
  ('Audit Reports',10,'Report issue date'),
  ('Invoices',8,'Financial year end'),
  ('Misc Documents',5,'Carton creation date');

INSERT INTO archival_policy (archival_policy) VALUES ('Banking'),('Country Specific'),('Standard');

INSERT INTO retention_policy (policy_id, document_type, archival_policy, retention_years) VALUES
  ('RET-001','Client KYC','Standard',8),
  ('RET-002','Client KYC','Country Specific',10),
  ('RET-003','Client KYC','Banking',10),
  ('RET-004','Loan Agreements','Standard',10),
  ('RET-005','Loan Agreements','Country Specific',12),
  ('RET-006','Loan Agreements','Banking',10),
  ('RET-007','Other Agreements and Vendor Data','Standard',7),
  ('RET-008','Other Agreements and Vendor Data','Country Specific',9),
  ('RET-009','Other Agreements and Vendor Data','Banking',10),
  ('RET-010','Vendor Onboarding','Standard',7),
  ('RET-011','Vendor Onboarding','Country Specific',9),
  ('RET-012','Vendor Onboarding','Banking',10),
  ('RET-013','Audit Reports','Standard',10),
  ('RET-014','Audit Reports','Country Specific',12),
  ('RET-015','Audit Reports','Banking',10),
  ('RET-016','Invoices','Standard',8),
  ('RET-017','Invoices','Country Specific',10),
  ('RET-018','Invoices','Banking',10),
  ('RET-019','Misc Documents','Standard',5),
  ('RET-020','Misc Documents','Country Specific',7),
  ('RET-021','Misc Documents','Banking',10);

INSERT INTO vendor_rate (vendor_id, activity, rate_inr, unit, effective_from, effective_to) VALUES
  ('VND-001','PICKUP','500','PER_CARTON','2024-04-01',NULL),
  ('VND-001','RETRIEVAL','500','PER_CARTON','2024-04-01',NULL),
  ('VND-001','DESTRUCTION','750','PER_CARTON','2024-04-01',NULL),
  ('VND-001','STORAGE','100','PER_CARTON_MONTH','2024-04-01','2026-04-01'),
  ('VND-001','STORAGE','108','PER_CARTON_MONTH','2026-04-01',NULL),
  ('VND-002','PICKUP','450','PER_CARTON','2024-04-01',NULL),
  ('VND-002','RETRIEVAL','550','PER_CARTON','2024-04-01',NULL),
  ('VND-002','DESTRUCTION','700','PER_CARTON','2024-04-01',NULL),
  ('VND-002','STORAGE','95','PER_CARTON_MONTH','2024-04-01',NULL),
  ('VND-003','PICKUP','520','PER_CARTON','2025-01-01',NULL),
  ('VND-003','RETRIEVAL','520','PER_CARTON','2025-01-01',NULL),
  ('VND-003','DESTRUCTION','800','PER_CARTON','2025-01-01',NULL),
  ('VND-003','STORAGE','110','PER_CARTON_MONTH','2025-01-01',NULL);

INSERT INTO sla_rule (activity, business_days, starts_on, ends_on, definition) VALUES
  ('PICKUP',2,'REQUEST_SUBMITTED','WAREHOUSE_RECEIPT','Business days from request to carton received at warehouse'),
  ('RETRIEVAL',2,'REQUEST_SUBMITTED','BUSINESS_DELIVERY','Business days from request to carton delivered to requester'),
  ('RETURN',2,'REQUEST_SUBMITTED','WAREHOUSE_RECEIPT','Business days from return request to carton back in storage'),
  ('DESTRUCTION',5,'DESTRUCTION_APPROVED','CERTIFICATE_ISSUED','Business days from approved destruction to certificate issued');

INSERT INTO holiday (holiday_date, holiday_name) VALUES
  ('2025-01-26','Republic Day'),('2025-03-14','Holi'),('2025-08-15','Independence Day'),
  ('2025-10-02','Gandhi Jayanti'),('2025-10-21','Diwali'),('2025-12-25','Christmas'),
  ('2026-01-26','Republic Day'),('2026-08-15','Independence Day'),('2026-10-02','Gandhi Jayanti');

INSERT INTO threshold_rule (threshold_id, applies_to, threshold_days, day_basis, meaning) VALUES
  ('THR-001','In Transit to Vendor',30,'CALENDAR','Collected but not receipted; far beyond pickup SLA - treat as possibly lost'),
  ('THR-002','With Business',90,'CALENDAR','Recalled and not returned; borrowing convention, not a contractual SLA'),
  ('THR-003','Request open',0,'CALENDAR','Request past its own sla_due_date; no grace period');

INSERT INTO tax_rule (tax_code, rate_percent, effective_from, effective_to) VALUES
  ('GST-18','18','2024-04-01',NULL);

INSERT INTO carton_status (status_code, meaning, is_terminal) VALUES
  ('Created','Carton registered by business; not yet collected',0),
  ('Pickup Requested','Pickup request raised, awaiting vendor',0),
  ('In Transit to Vendor','Collected by vendor, not yet receipted',0),
  ('In Storage','Held at vendor warehouse',0),
  ('Retrieval Requested','Retrieval raised, awaiting delivery',0),
  ('With Business','Physically with the requesting department',0),
  ('Return Requested','Return to vendor raised',0),
  ('Destruction Requested','Awaiting approval',0),
  ('Approved for Destruction','Approved, awaiting vendor execution',0),
  ('Destroyed','Terminal state, certificate issued',1),
  ('Missing','Exception state raised by reconciliation',0);

INSERT INTO event_type (event_type, meaning, changes_custody, expected_role, resulting_status, request_requirement) VALUES
  ('CARTON_CREATED','A carton is registered and its files indexed.',0,'BUSINESS','Created','No'),
  ('PICKUP_REQUESTED','Business asks the vendor to collect the carton.',0,'BUSINESS','Pickup Requested','Yes - PICKUP'),
  ('PICKED_UP_BY_VENDOR','Vendor confirms physical collection.',1,'VENDOR','In Transit to Vendor','Yes - PICKUP'),
  ('RECEIVED_AT_WAREHOUSE','Vendor confirms arrival/shelving at warehouse.',1,'VENDOR','In Storage','Yes - PICKUP or RETURN'),
  ('RETRIEVAL_REQUESTED','Business asks for a stored carton temporarily.',0,'BUSINESS','Retrieval Requested','Yes - RETRIEVAL'),
  ('DELIVERED_TO_BUSINESS','Vendor confirms delivery to business.',1,'VENDOR','With Business','Yes - RETRIEVAL'),
  ('RETURN_REQUESTED','Business asks the vendor to take the carton back.',0,'BUSINESS','Return Requested','Yes - RETURN'),
  ('DESTRUCTION_REQUESTED','Owner asks for destruction after retention.',0,'BUSINESS','Destruction Requested','Yes - DESTRUCTION'),
  ('DESTRUCTION_APPROVED','Compliance authorises the destruction.',0,'COMPLIANCE','Approved for Destruction','Yes - DESTRUCTION'),
  ('DESTROYED','Vendor destroys the carton and issues a certificate.',1,'VENDOR','Destroyed','Yes - DESTRUCTION'),
  ('INTER_WAREHOUSE_TRANSFER','Vendor moves a carton between its own warehouses.',1,'VENDOR','In Storage','No'),
  ('LEGAL_HOLD_APPLIED','Compliance freezes the carton against destruction.',0,'COMPLIANCE',NULL,'No'),
  ('LEGAL_HOLD_RELEASED','Compliance lifts the freeze.',0,'COMPLIANCE',NULL,'No'),
  ('REQUEST_ACKNOWLEDGED','Vendor acknowledgment',0,'VENDOR',NULL,'NONE'),
  ('REQUEST_REJECTED','Rejected instruction or approval',0,NULL,NULL,'NONE'),
  ('REQUEST_CANCELLED','Business cancellation',0,'BUSINESS',NULL,'NONE'),
  ('FILE_INDEXED','File index added or corrected',0,'BUSINESS',NULL,'NONE'),
  ('CERTIFICATE_LODGED','Evidence attachment, not a physical movement',0,'VENDOR',NULL,'NONE'),
  ('REFERENCE_CHANGED','Before/after configuration values',0,NULL,NULL,'NONE'),
  ('USER_ACCESS_CHANGED','Access assignment or deactivation',0,'FACILITIES',NULL,'NONE'),
  ('EXCEPTION_UPDATED','Investigation or resolution',0,NULL,NULL,'NONE'),
  ('RECONCILIATION_RUN','Recorded reconciliation request',0,'FACILITIES',NULL,'NONE'),
  ('CORRECTION_RECORDED','Compensating evidence; privileged reviewed process',0,NULL,NULL,'NONE');

INSERT INTO lifecycle_transition (from_status, event_type, to_status) VALUES
  ('Created','PICKUP_REQUESTED','Pickup Requested'),
  ('Pickup Requested','PICKED_UP_BY_VENDOR','In Transit to Vendor'),
  ('In Transit to Vendor','RECEIVED_AT_WAREHOUSE','In Storage'),
  ('In Storage','RETRIEVAL_REQUESTED','Retrieval Requested'),
  ('Retrieval Requested','DELIVERED_TO_BUSINESS','With Business'),
  ('With Business','RETURN_REQUESTED','Return Requested'),
  ('Return Requested','RECEIVED_AT_WAREHOUSE','In Storage'),
  ('In Storage','DESTRUCTION_REQUESTED','Destruction Requested'),
  ('Destruction Requested','DESTRUCTION_APPROVED','Approved for Destruction'),
  ('Approved for Destruction','DESTROYED','Destroyed'),
  ('In Storage','INTER_WAREHOUSE_TRANSFER','In Storage'),
  ('Pickup Requested','REQUEST_CANCELLED','Created'),
  ('Retrieval Requested','REQUEST_CANCELLED','In Storage'),
  ('Destruction Requested','REQUEST_REJECTED','In Storage');
