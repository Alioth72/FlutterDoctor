-- =====================================================================
-- ASHWINI / Rural Health — PostgreSQL schema for the Azure Functions backend
--
-- Reconstructed from the queries in doctor_app/backend/src/functions/*.ts
-- (the original server's DDL was never committed). CHECK constraints come
-- from the "per PostgreSQL check constraint" notes in the backend code.
--
-- Idempotent: safe to re-run. Requires PostgreSQL 13+ (gen_random_uuid()).
-- The database must be UTF8 (Azure's default): names and notes contain
-- non-Latin text (Hindi, ₹, ...).
-- Apply with:  psql "<connection string>" -v ON_ERROR_STOP=1 -f sql/schema.sql
-- =====================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS health;

-- ---------------------------------------------------------------------
-- users: every login (patients and staff)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.users (
    user_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    external_auth_id    text UNIQUE,
    role                text NOT NULL
        CHECK (role IN ('patient', 'doctor', 'nurse', 'volunteer', 'pharmacist', 'admin', 'family_member')),
    full_name           text NOT NULL,
    phone_e164          text UNIQUE,
    preferred_language  text NOT NULL DEFAULT 'en',
    date_of_birth       date,
    sex_at_birth        text,
    consent             jsonb NOT NULL DEFAULT '{}'::jsonb,
    profile_data        jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_active           boolean NOT NULL DEFAULT true,
    password_hash       text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON health.users (role);

-- ---------------------------------------------------------------------
-- patients: 1:1 with a users row of role 'patient'
-- medical_record_number = 14-digit Health ID, formatted 14-XXXX-XXXX-XXXX
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.patients (
    patient_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                uuid NOT NULL UNIQUE REFERENCES health.users (user_id),
    medical_record_number  text UNIQUE,
    blood_group            text,
    allergies              jsonb NOT NULL DEFAULT '[]'::jsonb,
    emergency_contact      jsonb NOT NULL DEFAULT '{}'::jsonb,
    disability_data        jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- staff_profiles: 1:1 with a users row of a staff role
-- license_number = NMC registration number for doctors (NMC-YYYY-NNNNNN)
-- specialties = JSON array of strings; availability = JSON object
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.staff_profiles (
    staff_profile_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           uuid NOT NULL UNIQUE REFERENCES health.users (user_id),
    staff_type        text NOT NULL
        CHECK (staff_type IN ('doctor', 'nurse', 'volunteer', 'pharmacist', 'admin')),
    license_number    text UNIQUE,
    specialties       jsonb NOT NULL DEFAULT '[]'::jsonb,
    availability      jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- facilities: clinics / hospitals / pharmacies
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.facilities (
    facility_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name             text NOT NULL,
    facility_type    text,
    address          jsonb NOT NULL DEFAULT '{}'::jsonb,
    contact_data     jsonb NOT NULL DEFAULT '{}'::jsonb,
    operating_hours  jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- appointments
-- notes (jsonb) carries appointment_no (APT-NNN), slot_time, appointment_date,
-- doctor_specialty, payment_status, pre_call_rppg, ...
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.appointments (
    appointment_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id           uuid NOT NULL REFERENCES health.patients (patient_id),
    provider_user_id     uuid REFERENCES health.users (user_id) ON DELETE SET NULL,
    facility_id          uuid REFERENCES health.facilities (facility_id),
    appointment_type     text NOT NULL DEFAULT 'clinic'
        CHECK (appointment_type IN ('clinic', 'telehealth', 'home_visit', 'pharmacy')),
    scheduled_start      timestamptz NOT NULL DEFAULT now(),
    scheduled_end        timestamptz,
    status               text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show')),
    reason               text,
    source               text NOT NULL DEFAULT 'online'
        CHECK (source IN ('online', 'offline_sync', 'system')),
    client_operation_id  uuid UNIQUE,
    notes                jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_appointments_patient   ON health.appointments (patient_id, scheduled_start DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_provider  ON health.appointments (provider_user_id, status, scheduled_start);
CREATE INDEX IF NOT EXISTS idx_appointments_status    ON health.appointments (status);
CREATE INDEX IF NOT EXISTS idx_appointments_appt_no   ON health.appointments ((notes->>'appointment_no'));

-- ---------------------------------------------------------------------
-- medical_records
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.medical_records (
    medical_record_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id         uuid NOT NULL REFERENCES health.patients (patient_id),
    author_user_id     uuid REFERENCES health.users (user_id) ON DELETE SET NULL,
    appointment_id     uuid REFERENCES health.appointments (appointment_id) ON DELETE SET NULL,
    record_type        text NOT NULL
        CHECK (record_type IN ('triage', 'diagnosis', 'progress_note', 'lab_result', 'imaging', 'discharge')),
    recorded_at        timestamptz NOT NULL DEFAULT now(),
    diagnosis          text,
    symptoms           jsonb NOT NULL DEFAULT '[]'::jsonb,
    clinical_data      jsonb NOT NULL DEFAULT '{}'::jsonb,
    confidence         numeric(4,3),
    is_preliminary     boolean NOT NULL DEFAULT false,
    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_medical_records_patient      ON health.medical_records (patient_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_records_appointment  ON health.medical_records (appointment_id);

-- ---------------------------------------------------------------------
-- prescriptions
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.prescriptions (
    prescription_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            uuid NOT NULL REFERENCES health.patients (patient_id),
    prescriber_user_id    uuid REFERENCES health.users (user_id) ON DELETE SET NULL,
    appointment_id        uuid REFERENCES health.appointments (appointment_id) ON DELETE SET NULL,
    pharmacy_facility_id  uuid REFERENCES health.facilities (facility_id),
    medication_name       text NOT NULL,
    dosage                text,
    route                 text,
    frequency             text,
    duration_days         integer,
    instructions          jsonb NOT NULL DEFAULT '{}'::jsonb,
    status                text NOT NULL DEFAULT 'active',
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prescriptions_patient      ON health.prescriptions (patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prescriptions_appointment  ON health.prescriptions (appointment_id);

-- ---------------------------------------------------------------------
-- inventory (pharmacy stock per facility)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.inventory (
    inventory_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id    uuid NOT NULL REFERENCES health.facilities (facility_id),
    item_code      text,
    item_name      text NOT NULL,
    category       text,
    quantity       integer NOT NULL DEFAULT 0,
    reorder_level  integer NOT NULL DEFAULT 0,
    unit           text,
    expiry_date    date,
    batch_number   text,
    metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_facility ON health.inventory (facility_id, category);

-- ---------------------------------------------------------------------
-- machine_records (equipment per facility)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.machine_records (
    machine_record_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id        uuid NOT NULL REFERENCES health.facilities (facility_id),
    machine_type       text NOT NULL,
    serial_number      text,
    status             text,
    last_service_at    timestamptz,
    telemetry          jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_machine_records_facility ON health.machine_records (facility_id, status);

-- ---------------------------------------------------------------------
-- hospital_stays / consultations_colleague
-- The backend only references the appointment FK on these (it detaches them
-- before deleting an appointment). Columns beyond the keys are minimal
-- placeholders; extend when a feature starts reading/writing them.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health.hospital_stays (
    hospital_stay_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id                uuid NOT NULL REFERENCES health.patients (patient_id),
    facility_id               uuid REFERENCES health.facilities (facility_id),
    admitting_appointment_id  uuid REFERENCES health.appointments (appointment_id) ON DELETE SET NULL,
    admitted_at               timestamptz NOT NULL DEFAULT now(),
    discharged_at             timestamptz,
    care_plan                 jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS health.consultations_colleague (
    consultation_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id        uuid REFERENCES health.appointments (appointment_id) ON DELETE SET NULL,
    requesting_user_id    uuid REFERENCES health.users (user_id) ON DELETE SET NULL,
    consulted_user_id     uuid REFERENCES health.users (user_id) ON DELETE SET NULL,
    notes                 jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMIT;
