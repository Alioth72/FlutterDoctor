import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query, pool } from "../db";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";
import { authenticate } from "../utils/auth";
import { TokenPayload } from "../utils/token";

// GET /api/me/appointments (Returns authenticated patient's appointments)
export async function getMyAppointments(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }
    const auth = authResult as TokenPayload;

    if (!auth.patient_id) {
        return errorResponse(403, "Only patient accounts can access personal appointments.");
    }

    try {
        const sql = `
            SELECT 
                a.appointment_id,
                a.patient_id,
                pu.full_name AS patient_name,
                pu.phone_e164 AS patient_phone,
                pu.date_of_birth AS patient_dob,
                pu.sex_at_birth AS patient_sex,
                p.medical_record_number,
                p.blood_group,
                p.allergies,
                p.emergency_contact,
                a.provider_user_id,
                du.full_name AS doctor_name,
                COALESCE(ds.specialties->>0, a.notes->>'doctor_specialty', 'General Physician') AS doctor_specialty,
                a.facility_id,
                f.name AS facility_name,
                a.appointment_type,
                a.scheduled_start,
                a.scheduled_end,
                a.status,
                COALESCE(a.reason, mr.diagnosis, 'Clinical Consultation') AS reason,
                a.source,
                a.notes,
                a.created_at,
                a.updated_at,
                mr.diagnosis AS mr_diagnosis,
                mr.clinical_data,
                (
                  SELECT json_agg(json_build_object(
                    'medication_name', rx.medication_name,
                    'dosage', rx.dosage,
                    'frequency', rx.frequency,
                    'duration_days', rx.duration_days,
                    'instructions', rx.instructions,
                    'closest_clinic', COALESCE(rxf.name, f.name, 'Ashwini Central Pharmacy')
                  ))
                  FROM health.prescriptions rx
                  LEFT JOIN health.facilities rxf ON rx.pharmacy_facility_id = rxf.facility_id
                  WHERE rx.appointment_id = a.appointment_id
                     OR (rx.appointment_id IS NULL AND rx.patient_id = a.patient_id AND NOT EXISTS (SELECT 1 FROM health.prescriptions WHERE appointment_id = a.appointment_id))
                ) AS prescriptions
            FROM health.appointments a
            JOIN health.patients p ON a.patient_id = p.patient_id
            JOIN health.users pu ON p.user_id = pu.user_id
            LEFT JOIN health.users du ON a.provider_user_id = du.user_id
            LEFT JOIN health.staff_profiles ds ON du.user_id = ds.user_id
            LEFT JOIN health.facilities f ON a.facility_id = f.facility_id
            LEFT JOIN LATERAL (
              SELECT diagnosis, clinical_data
              FROM health.medical_records
              WHERE patient_id = a.patient_id OR appointment_id = a.appointment_id
              ORDER BY recorded_at DESC
              LIMIT 1
            ) mr ON true
            WHERE a.patient_id = $1::uuid
            ORDER BY a.scheduled_start DESC;
        `;

        const result = await query(sql, [auth.patient_id]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getMyAppointments:", err);
        return errorResponse(500, "Internal server error fetching patient appointments.");
    }
}

// GET /api/appointments
export async function getAppointments(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }
    const auth = authResult as TokenPayload;

    try {
        const status = request.query.get("status") || null;
        const providerUserId = request.query.get("provider_user_id") || null;
        const patientId = request.query.get("patient_id") || null;

        if (providerUserId && !isValidUuid(providerUserId)) {
            return errorResponse(400, "Invalid provider_user_id format. Must be a valid UUID.");
        }
        if (patientId && !isValidUuid(patientId)) {
            return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
        }

        // Ownership enforcement: if caller is a patient, they can only query their own appointments
        if (auth.role === "patient") {
            if (patientId && patientId !== auth.patient_id) {
                return errorResponse(403, "Forbidden. Patients can only query their own appointments.");
            }
        }
        const effectivePatientId = auth.role === "patient" ? auth.patient_id : patientId;

        const sql = `
            SELECT 
                a.appointment_id,
                a.patient_id,
                pu.full_name AS patient_name,
                pu.phone_e164 AS patient_phone,
                pu.date_of_birth AS patient_dob,
                pu.sex_at_birth AS patient_sex,
                p.medical_record_number,
                p.blood_group,
                p.allergies,
                p.emergency_contact,
                a.provider_user_id,
                du.full_name AS doctor_name,
                a.facility_id,
                f.name AS facility_name,
                a.appointment_type,
                a.scheduled_start,
                a.scheduled_end,
                a.status,
                COALESCE(a.reason, mr.diagnosis, 'Clinical Consultation') AS reason,
                a.source,
                a.notes,
                a.created_at,
                a.updated_at,
                mr.diagnosis AS mr_diagnosis,
                mr.clinical_data,
                (
                  SELECT json_agg(json_build_object(
                    'medication_name', rx.medication_name,
                    'dosage', rx.dosage,
                    'frequency', rx.frequency,
                    'duration_days', rx.duration_days,
                    'instructions', rx.instructions,
                    'closest_clinic', COALESCE(rxf.name, f.name, 'Ashwini Central Pharmacy')
                  ))
                  FROM health.prescriptions rx
                  LEFT JOIN health.facilities rxf ON rx.pharmacy_facility_id = rxf.facility_id
                  WHERE rx.appointment_id = a.appointment_id
                     OR (rx.appointment_id IS NULL AND rx.patient_id = a.patient_id AND NOT EXISTS (SELECT 1 FROM health.prescriptions WHERE appointment_id = a.appointment_id))
                ) AS prescriptions
            FROM health.appointments a
            JOIN health.patients p ON a.patient_id = p.patient_id
            JOIN health.users pu ON p.user_id = pu.user_id
            LEFT JOIN health.users du ON a.provider_user_id = du.user_id
            LEFT JOIN health.facilities f ON a.facility_id = f.facility_id
            LEFT JOIN LATERAL (
              SELECT diagnosis, clinical_data
              FROM health.medical_records
              WHERE patient_id = a.patient_id OR appointment_id = a.appointment_id
              ORDER BY recorded_at DESC
              LIMIT 1
            ) mr ON true
            WHERE ($1::text IS NULL OR a.status = $1)
              AND ($2::uuid IS NULL OR a.provider_user_id = $2)
              AND ($3::uuid IS NULL OR a.patient_id = $3)
            ORDER BY a.scheduled_start ASC;
        `;

        const result = await query(sql, [status, providerUserId, effectivePatientId]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getAppointments:", err);
        return errorResponse(500, "Internal server error fetching appointments.");
    }
}

// GET /api/appointments/{appointment_id}
export async function getAppointmentById(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }
    const auth = authResult as TokenPayload;

    try {
        const appointmentId = request.params.appointment_id;

        if (!isValidUuid(appointmentId)) {
            return errorResponse(400, "Invalid appointment_id format. Must be a valid UUID.");
        }

        const sql = `
            SELECT 
                a.appointment_id,
                a.patient_id,
                pu.full_name AS patient_name,
                pu.phone_e164 AS patient_phone,
                pu.date_of_birth AS patient_dob,
                pu.sex_at_birth AS patient_sex,
                p.medical_record_number,
                p.blood_group,
                p.allergies,
                p.emergency_contact,
                a.provider_user_id,
                du.full_name AS doctor_name,
                a.facility_id,
                f.name AS facility_name,
                a.appointment_type,
                a.scheduled_start,
                a.scheduled_end,
                a.status,
                COALESCE(a.reason, mr.diagnosis, 'Clinical Consultation') AS reason,
                a.source,
                a.notes,
                a.created_at,
                a.updated_at,
                mr.diagnosis AS mr_diagnosis,
                mr.clinical_data,
                (
                  SELECT json_agg(json_build_object(
                    'medication_name', rx.medication_name,
                    'dosage', rx.dosage,
                    'frequency', rx.frequency,
                    'duration_days', rx.duration_days,
                    'instructions', rx.instructions,
                    'closest_clinic', COALESCE(rxf.name, f.name, 'Ashwini Central Pharmacy')
                  ))
                  FROM health.prescriptions rx
                  LEFT JOIN health.facilities rxf ON rx.pharmacy_facility_id = rxf.facility_id
                  WHERE rx.appointment_id = a.appointment_id
                     OR (rx.appointment_id IS NULL AND rx.patient_id = a.patient_id AND NOT EXISTS (SELECT 1 FROM health.prescriptions WHERE appointment_id = a.appointment_id))
                ) AS prescriptions
            FROM health.appointments a
            JOIN health.patients p ON a.patient_id = p.patient_id
            JOIN health.users pu ON p.user_id = pu.user_id
            LEFT JOIN health.users du ON a.provider_user_id = du.user_id
            LEFT JOIN health.facilities f ON a.facility_id = f.facility_id
            LEFT JOIN LATERAL (
              SELECT diagnosis, clinical_data
              FROM health.medical_records
              WHERE patient_id = a.patient_id OR appointment_id = a.appointment_id
              ORDER BY recorded_at DESC
              LIMIT 1
            ) mr ON true
            WHERE a.appointment_id = $1::uuid;
        `;

        const result = await query(sql, [appointmentId]);
        if (result.rows.length === 0) {
            return errorResponse(404, `Appointment with ID ${appointmentId} not found.`);
        }

        const appointment = result.rows[0];
        if (auth.role === "patient" && appointment.patient_id !== auth.patient_id) {
            return errorResponse(403, "Forbidden. Patients can only view their own appointments.");
        }

        return jsonResponse(200, {
            success: true,
            data: appointment,
        });
    } catch (err: any) {
        context.error("Error in getAppointmentById:", err);
        return errorResponse(500, "Internal server error fetching appointment.");
    }
}

// Allowed appointment status values per PostgreSQL check constraint
const VALID_APPOINTMENT_STATUSES = new Set([
    "queued",
    "confirmed",
    "in_progress",
    "completed",
    "cancelled",
    "no_show",
]);

// PATCH /api/appointments/{appointment_id}
export async function updateAppointment(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // 1. Authenticate JWT Bearer Token (401 on failure)
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;

    // 2. Authorize role: only doctor or admin can modify appointments (403 for other roles)
    if (authPayload.role !== "doctor" && authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Only doctors and administrators can modify appointments.");
    }

    try {
        const appointmentId = request.params.appointment_id;

        // 3. Validate appointment_id UUID format
        if (!isValidUuid(appointmentId)) {
            return errorResponse(400, "Invalid appointment_id format. Must be a valid UUID.");
        }

        // 4. Fetch existing appointment to verify existence and check ownership
        const existingResult = await query(
            `SELECT appointment_id, patient_id, provider_user_id, status, notes, scheduled_start, scheduled_end, reason
             FROM health.appointments
             WHERE appointment_id = $1::uuid`,
            [appointmentId]
        );

        if (existingResult.rows.length === 0) {
            return errorResponse(404, `Appointment with ID ${appointmentId} not found.`);
        }

        const existingAppt = existingResult.rows[0];

        // 5. Enforce Doctor ownership: doctor can ONLY modify their own appointment
        if (authPayload.role === "doctor" && existingAppt.provider_user_id !== authPayload.user_id) {
            return errorResponse(403, "Access denied. You are not authorized to modify another doctor's appointment.");
        }

        // 6. Parse JSON request body
        let body: any = {};
        try {
            body = await request.json();
        } catch {
            return errorResponse(400, "Invalid JSON payload in request body.");
        }

        const {
            status,
            scheduled_start,
            scheduled_end,
            reason,
            notes,
        } = body;

        // Strict security checks: Do NOT allow modifying patient_id or provider_user_id
        if (body.patient_id !== undefined && body.patient_id !== existingAppt.patient_id) {
            return errorResponse(400, "Cannot change patient_id of an existing appointment.");
        }
        if (body.provider_user_id !== undefined && body.provider_user_id !== existingAppt.provider_user_id) {
            return errorResponse(400, "Cannot change provider_user_id. Reassignment is not permitted via this endpoint.");
        }

        // 7. Validate status if provided
        let newStatus = existingAppt.status;
        if (status !== undefined) {
            if (typeof status !== "string" || !VALID_APPOINTMENT_STATUSES.has(status.toLowerCase())) {
                return errorResponse(
                    400,
                    `Invalid status '${status}'. Supported statuses: queued, confirmed, in_progress, completed, cancelled, no_show.`
                );
            }
            newStatus = status.toLowerCase();
        }

        // 8. Validate scheduled_start / scheduled_end if provided
        let newStart = existingAppt.scheduled_start;
        if (scheduled_start !== undefined) {
            const parsedStart = new Date(scheduled_start);
            if (isNaN(parsedStart.getTime())) {
                return errorResponse(400, "Invalid scheduled_start date/time format. Must be a valid ISO-8601 string.");
            }
            newStart = parsedStart.toISOString();
        }

        let newEnd = existingAppt.scheduled_end;
        if (scheduled_end !== undefined) {
            if (scheduled_end === null) {
                newEnd = null;
            } else {
                const parsedEnd = new Date(scheduled_end);
                if (isNaN(parsedEnd.getTime())) {
                    return errorResponse(400, "Invalid scheduled_end date/time format. Must be a valid ISO-8601 string.");
                }
                newEnd = parsedEnd.toISOString();
            }
        }

        // 9. Reason
        let newReason = existingAppt.reason;
        if (reason !== undefined) {
            newReason = reason !== null ? String(reason).trim() : null;
        }

        // 10. Merge notes (JSONB) safely
        let mergedNotes = existingAppt.notes || {};
        if (notes !== undefined) {
            if (typeof notes !== "object" || notes === null || Array.isArray(notes)) {
                return errorResponse(400, "Field 'notes' must be a valid JSON object.");
            }
            mergedNotes = {
                ...mergedNotes,
                ...notes,
            };
        }

        // 11. Extract prescriptions if provided
        const rxList = body.prescriptions || body.medicines;
        if (Array.isArray(rxList) && rxList.length > 0) {
            mergedNotes['medicines'] = rxList.map((item: any) => ({
                name: String(item.medication_name || item.name || '').trim(),
                dosage: String(item.dosage || '1 tablet').trim(),
                duration: typeof item.duration_days === 'number' ? `${item.duration_days} Days` : String(item.duration || '5 Days'),
                closestClinic: item.closestClinic || 'Ashwini Central Pharmacy',
            }));
        }

        // 12. Execute parameterized update with transaction
        const client = await pool.connect();
        try {
            await client.query("BEGIN;");

            const updateSql = `
                UPDATE health.appointments
                SET status = $1,
                    scheduled_start = $2,
                    scheduled_end = $3,
                    reason = $4,
                    notes = $5::jsonb,
                    updated_at = NOW()
                WHERE appointment_id = $6::uuid
                RETURNING *;
            `;

            const updateResult = await client.query(updateSql, [
                newStatus,
                newStart,
                newEnd,
                newReason,
                JSON.stringify(mergedNotes),
                appointmentId,
            ]);

            const updatedAppt = updateResult.rows[0];
            const savedPrescriptions: any[] = [];

            if (Array.isArray(rxList) && rxList.length > 0) {
                // Delete previous prescriptions specifically linked to this appointment to prevent duplicate entries
                await client.query(
                    `DELETE FROM health.prescriptions WHERE appointment_id = $1::uuid;`,
                    [appointmentId]
                );

                for (const item of rxList) {
                    const medName = String(item.medication_name || item.name || "").trim();
                    if (!medName) continue;

                    const dosage = String(item.dosage || "1 tablet").trim();
                    const frequency = String(item.frequency || item.dosage || "1-0-1").trim();
                    const durationDays = typeof item.duration_days === "number" && item.duration_days > 0
                        ? item.duration_days
                        : (parseInt(String(item.duration || "").replace(/\D/g, ""), 10) || 5);
                    const route = String(item.route || "oral").trim();
                    const instructions = typeof item.instructions === "object" && item.instructions !== null
                        ? item.instructions
                        : { timing: dosage, clinic: item.closestClinic || "Ashwini Central Pharmacy" };

                    const rxInsertSql = `
                        INSERT INTO health.prescriptions (
                            patient_id, prescriber_user_id, appointment_id,
                            medication_name, dosage, route, frequency, duration_days, instructions, status
                        ) VALUES (
                            $1::uuid, $2::uuid, $3::uuid,
                            $4, $5, $6, $7, $8, $9::jsonb, 'active'
                        ) RETURNING *;
                    `;

                    const rxRes = await client.query(rxInsertSql, [
                        existingAppt.patient_id,
                        existingAppt.provider_user_id,
                        appointmentId,
                        medName,
                        dosage,
                        route,
                        frequency,
                        durationDays,
                        JSON.stringify(instructions),
                    ]);
                    savedPrescriptions.push(rxRes.rows[0]);
                }
            }

            await client.query("COMMIT;");

            return jsonResponse(200, {
                success: true,
                message: "Appointment updated successfully.",
                data: {
                    ...updatedAppt,
                    prescriptions: savedPrescriptions,
                },
            });
        } catch (txErr: any) {
            await client.query("ROLLBACK;");
            throw txErr;
        } finally {
            client.release();
        }
    } catch (err: any) {
        context.error("Error in updateAppointment:", err);
        return errorResponse(500, `Internal server error updating appointment: ${err.message}`);
    }
}

// DELETE /api/appointments/{appointment_id} (Admin Only Delete from Database)
export async function deleteAppointment(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Only administrators can delete consultations/appointments from the database.");
    }

    const appointmentId = request.params.appointment_id;
    if (!isValidUuid(appointmentId)) {
        return errorResponse(400, "Invalid appointment_id format. Must be a valid UUID.");
    }

    try {
        // Verify appointment exists
        const checkResult = await query(
            `SELECT appointment_id, patient_id, provider_user_id, status FROM health.appointments WHERE appointment_id = $1::uuid;`,
            [appointmentId]
        );
        if (checkResult.rows.length === 0) {
            return errorResponse(404, `Appointment with ID ${appointmentId} not found.`);
        }

        // Safely unlink any child FK references before deletion
        await query(`UPDATE health.prescriptions SET appointment_id = NULL WHERE appointment_id = $1::uuid;`, [appointmentId]);
        await query(`UPDATE health.medical_records SET appointment_id = NULL WHERE appointment_id = $1::uuid;`, [appointmentId]);
        await query(`UPDATE health.hospital_stays SET admitting_appointment_id = NULL WHERE admitting_appointment_id = $1::uuid;`, [appointmentId]);
        await query(`UPDATE health.consultations_colleague SET appointment_id = NULL WHERE appointment_id = $1::uuid;`, [appointmentId]);

        // Permanently delete the appointment
        const deleteResult = await query(
            `DELETE FROM health.appointments WHERE appointment_id = $1::uuid RETURNING *;`,
            [appointmentId]
        );

        context.log(`Admin ${authPayload.user_id} deleted appointment ${appointmentId} from database.`);

        return jsonResponse(200, {
            success: true,
            message: `Consultation/appointment ${appointmentId} successfully deleted from the database.`,
            data: deleteResult.rows[0],
        });
    } catch (err: any) {
        context.error("Error in deleteAppointment:", err);
        return errorResponse(500, "Internal server error deleting appointment from database.");
    }
}

// Allowed appointment types per PostgreSQL check constraint
const VALID_APPOINTMENT_TYPES = new Set([
    "clinic",
    "telehealth",
    "home_visit",
    "pharmacy",
]);

// Allowed appointment sources per PostgreSQL check constraint
const VALID_APPOINTMENT_SOURCES = new Set([
    "online",
    "offline_sync",
    "system",
]);

async function generateUniqueAppointmentNumber(): Promise<string> {
    for (let i = 0; i < 30; i++) {
        const num = Math.floor(100 + Math.random() * 900);
        const candidate = `APT-${num}`;
        const check = await query(
            `SELECT 1 FROM health.appointments WHERE notes->>'appointment_no' = $1 LIMIT 1;`,
            [candidate]
        );
        if (check.rows.length === 0) {
            return candidate;
        }
    }
    return `APT-${Date.now().toString().slice(-4)}`;
}

async function fetchFullAppointment(appointmentId: string): Promise<any> {
    const sql = `
        SELECT 
            a.appointment_id,
            a.patient_id,
            pu.full_name AS patient_name,
            pu.phone_e164 AS patient_phone,
            pu.date_of_birth AS patient_dob,
            pu.sex_at_birth AS patient_sex,
            p.medical_record_number,
            p.blood_group,
            p.allergies,
            p.emergency_contact,
            a.provider_user_id,
            du.full_name AS doctor_name,
            COALESCE(ds.specialties->>0, a.notes->>'doctor_specialty', 'General Physician') AS doctor_specialty,
            a.facility_id,
            f.name AS facility_name,
            a.appointment_type,
            a.scheduled_start,
            a.scheduled_end,
            a.status,
            COALESCE(a.reason, mr.diagnosis, 'Clinical Consultation') AS reason,
            a.source,
            a.notes,
            a.created_at,
            a.updated_at,
            mr.diagnosis AS mr_diagnosis,
            mr.clinical_data
        FROM health.appointments a
        JOIN health.patients p ON a.patient_id = p.patient_id
        JOIN health.users pu ON p.user_id = pu.user_id
        LEFT JOIN health.users du ON a.provider_user_id = du.user_id
        LEFT JOIN health.staff_profiles ds ON du.user_id = ds.user_id
        LEFT JOIN health.facilities f ON a.facility_id = f.facility_id
        LEFT JOIN LATERAL (
          SELECT diagnosis, clinical_data
          FROM health.medical_records
          WHERE patient_id = a.patient_id OR appointment_id = a.appointment_id
          ORDER BY recorded_at DESC
          LIMIT 1
        ) mr ON true
        WHERE a.appointment_id = $1::uuid;
    `;
    const res = await query(sql, [appointmentId]);
    return res.rows[0] || null;
}

// POST /api/appointments
export async function createAppointment(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // 1. Authenticate Bearer token
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;

    // 2. Strict Role Authorization Enforcement
    // Worker: CREATE appointment ✅
    // Admin: CREATE appointment ✅
    // Patient: CREATE appointment for self ✅
    // Doctor: CREATE appointment ❌
    if (authPayload.role === "doctor") {
        return errorResponse(403, "Access denied. Doctors are not authorized to create appointments.");
    }
    if (authPayload.role !== "worker" && authPayload.role !== "nurse" && authPayload.role !== "admin" && authPayload.role !== "patient") {
        return errorResponse(403, "Access denied. Only healthcare workers, administrators, and patients can create appointments.");
    }

    // 3. Parse JSON Body
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const {
        patient_id,
        provider_user_id,
        doctor_user_id,
        facility_id,
        appointment_type = "clinic",
        scheduled_start,
        scheduled_end,
        status = "confirmed",
        reason,
        source = "online",
        client_operation_id,
        notes = {},
    } = body;

    // 4. Resolve & Validate effective patient_id
    let effectivePatientId = patient_id;
    if (authPayload.role === "patient") {
        if (authPayload.patient_id && isValidUuid(authPayload.patient_id)) {
            effectivePatientId = authPayload.patient_id;
        } else {
            const patCheck = await query(
                `SELECT patient_id FROM health.patients WHERE user_id = $1::uuid LIMIT 1;`,
                [authPayload.user_id]
            );
            if (patCheck.rows.length > 0) {
                effectivePatientId = patCheck.rows[0].patient_id;
            } else {
                const mrn = `MRN-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;
                const newPat = await query(
                    `INSERT INTO health.patients (user_id, medical_record_number) VALUES ($1::uuid, $2) RETURNING patient_id;`,
                    [authPayload.user_id, mrn]
                );
                effectivePatientId = newPat.rows[0].patient_id;
            }
        }
    } else {
        if (!effectivePatientId || !isValidUuid(effectivePatientId)) {
            return errorResponse(400, "Field 'patient_id' is required and must be a valid UUID.");
        }
    }

    if (!effectivePatientId || !isValidUuid(effectivePatientId)) {
        return errorResponse(400, "Field 'patient_id' is required and must be a valid UUID.");
    }

    const patientCheck = await query(
        `SELECT p.patient_id, u.full_name AS patient_name
         FROM health.patients p
         JOIN health.users u ON p.user_id = u.user_id
         WHERE p.patient_id = $1::uuid;`,
        [effectivePatientId]
    );
    if (patientCheck.rows.length === 0) {
        return errorResponse(404, `Patient with ID '${effectivePatientId}' not found.`);
    }
    const patientName = patientCheck.rows[0].patient_name;

    // 5. Validate provider_user_id (doctor)
    const effectiveDoctorId = provider_user_id || doctor_user_id || null;
    let doctorName: string | null = null;
    if (effectiveDoctorId) {
        if (!isValidUuid(effectiveDoctorId)) {
            return errorResponse(400, "Field 'provider_user_id' must be a valid UUID.");
        }
        const docCheck = await query(
            `SELECT user_id, full_name, role FROM health.users WHERE user_id = $1::uuid AND role = 'doctor';`,
            [effectiveDoctorId]
        );
        if (docCheck.rows.length === 0) {
            return errorResponse(400, `Doctor with user_id '${effectiveDoctorId}' not found or is not a doctor.`);
        }
        doctorName = docCheck.rows[0].full_name;
    }

    // 6. Validate facility_id
    let effectiveFacilityId = facility_id || null;
    if (effectiveFacilityId) {
        if (!isValidUuid(effectiveFacilityId)) {
            return errorResponse(400, "Field 'facility_id' must be a valid UUID.");
        }
        const facCheck = await query(
            `SELECT facility_id, name FROM health.facilities WHERE facility_id = $1::uuid;`,
            [effectiveFacilityId]
        );
        if (facCheck.rows.length === 0) {
            return errorResponse(400, `Facility with facility_id '${effectiveFacilityId}' not found.`);
        }
    } else {
        // Default to Ashwini Central Hospital if available
        const defaultFac = await query(
            `SELECT facility_id FROM health.facilities WHERE name ILIKE '%Ashwini%' LIMIT 1;`
        );
        if (defaultFac.rows.length > 0) {
            effectiveFacilityId = defaultFac.rows[0].facility_id;
        }
    }

    // 7. Validate appointment_type
    const apptType = String(appointment_type).toLowerCase().trim();
    if (!VALID_APPOINTMENT_TYPES.has(apptType)) {
        return errorResponse(
            400,
            `Invalid appointment_type '${appointment_type}'. Supported types: clinic, telehealth, home_visit, pharmacy.`
        );
    }

    // 8. Validate status
    const apptStatus = String(status).toLowerCase().trim();
    if (!VALID_APPOINTMENT_STATUSES.has(apptStatus)) {
        return errorResponse(
            400,
            `Invalid status '${status}'. Supported statuses: queued, confirmed, in_progress, completed, cancelled, no_show.`
        );
    }

    // 9. Validate source
    const apptSource = String(source).toLowerCase().trim();
    if (!VALID_APPOINTMENT_SOURCES.has(apptSource)) {
        return errorResponse(
            400,
            `Invalid source '${source}'. Supported sources: online, offline_sync, system.`
        );
    }

    // 10. Validate scheduled_start / scheduled_end
    let finalStart: string;
    if (scheduled_start) {
        const parsedStart = new Date(scheduled_start);
        if (isNaN(parsedStart.getTime())) {
            return errorResponse(400, "Invalid scheduled_start date/time format. Must be a valid ISO-8601 string.");
        }
        finalStart = parsedStart.toISOString();
    } else {
        finalStart = new Date().toISOString();
    }

    let finalEnd: string | null = null;
    if (scheduled_end) {
        const parsedEnd = new Date(scheduled_end);
        if (isNaN(parsedEnd.getTime())) {
            return errorResponse(400, "Invalid scheduled_end date/time format. Must be a valid ISO-8601 string.");
        }
        finalEnd = parsedEnd.toISOString();
    }

    // 11. Validate client_operation_id
    if (client_operation_id && !isValidUuid(client_operation_id)) {
        return errorResponse(400, "Field 'client_operation_id' must be a valid UUID.");
    }

    // 12. Build Notes JSONB object
    let mergedNotes: Record<string, any> = {};
    if (notes && typeof notes === "object" && !Array.isArray(notes)) {
        mergedNotes = { ...notes };
    }

    const aptNo = await generateUniqueAppointmentNumber();
    mergedNotes["appointment_no"] = mergedNotes["appointment_no"] || aptNo;
    mergedNotes["payment_status"] = mergedNotes["payment_status"] || "Payment Pending";
    const isWorker = authPayload.role === "worker" || authPayload.role === "nurse";
    const isPatient = authPayload.role === "patient";
    mergedNotes["created_by_role"] = isWorker ? "worker" : (isPatient ? "patient" : authPayload.role);
    mergedNotes["created_by_user_id"] = authPayload.user_id;
    mergedNotes["created_by_name"] = authPayload.full_name || (isWorker ? "Healthcare Worker" : (isPatient ? "Patient Online" : "Administrator"));

    // Extract or infer slot_time for 30-minute capacity tracking
    const slotTime = mergedNotes["slot_time"] || body.time_slot || formatSlotTime(new Date(finalStart));
    mergedNotes["slot_time"] = slotTime;
    mergedNotes["appointment_date"] = body.appointment_date || mergedNotes["appointment_date"] || finalStart.slice(0, 10);

    // 13. ATOMIC TRANSACTION & 3-PATIENT CAPACITY ENFORCEMENT
    // Enforces maximum of 3 active patients per doctor per 30-minute slot
    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        if (effectiveDoctorId) {
            const dateOnly = finalStart.slice(0, 10);
            const lockKey = `slot_${effectiveDoctorId}_${dateOnly}_${slotTime}`;
            // Acquire transaction-scoped advisory lock for this doctor's slot
            await client.query("SELECT pg_advisory_xact_lock(hashtext($1));", [lockKey]);

            // Query active bookings in this 30-minute window
            const slotCheckSql = `
                SELECT count(*)::int as active_count
                FROM health.appointments
                WHERE provider_user_id = $1::uuid
                  AND status IN ('queued', 'confirmed', 'in_progress')
                  AND (
                    notes->>'slot_time' = $2
                    OR (
                      scheduled_start >= $3::timestamptz - INTERVAL '14 minutes'
                      AND scheduled_start <= $3::timestamptz + INTERVAL '14 minutes'
                    )
                  );
            `;
            const slotRes = await client.query(slotCheckSql, [effectiveDoctorId, slotTime, finalStart]);
            const activeCount = slotRes.rows[0]?.active_count || 0;

            if (activeCount >= 3) {
                await client.query("ROLLBACK;");
                return errorResponse(
                    409,
                    `Time slot '${slotTime}' is full (maximum 3 patients per 30-minute slot). Please choose another time slot.`
                );
            }
        }

        const insertSql = `
            INSERT INTO health.appointments (
                patient_id,
                provider_user_id,
                facility_id,
                appointment_type,
                scheduled_start,
                scheduled_end,
                status,
                reason,
                source,
                client_operation_id,
                notes
            ) VALUES (
                $1::uuid,
                $2::uuid,
                $3::uuid,
                $4,
                $5,
                $6,
                $7,
                $8,
                $9,
                $10::uuid,
                $11::jsonb
            ) RETURNING appointment_id;
        `;

        const insertResult = await client.query(insertSql, [
            effectivePatientId,
            effectiveDoctorId,
            effectiveFacilityId,
            apptType,
            finalStart,
            finalEnd,
            apptStatus,
            reason ? String(reason).trim() : "Clinical Consultation",
            apptSource,
            client_operation_id || null,
            JSON.stringify(mergedNotes),
        ]);

        await client.query("COMMIT;");

        const newAppointmentId = insertResult.rows[0].appointment_id;
        const fullAppointment = await fetchFullAppointment(newAppointmentId);

        context.log(
            `Appointment ${newAppointmentId} created by ${authPayload.role} (${authPayload.user_id}) for patient ${patientName} with doctor ${doctorName || "Unassigned"}`
        );

        return jsonResponse(201, {
            success: true,
            message: `Appointment successfully created (${aptNo}).`,
            data: fullAppointment,
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error inserting appointment:", err);
        return errorResponse(500, `Internal server error creating appointment: ${err.message}`);
    } finally {
        client.release();
    }
}

// Format time string to '09:00 AM'
function formatSlotTime(d: Date): string {
    const hours = d.getHours();
    const minutes = d.getMinutes();
    const period = hours >= 12 ? "PM" : "AM";
    const h = hours % 12 === 0 ? 12 : hours % 12;
    const m = minutes.toString().padStart(2, "0");
    return `${h.toString().padStart(2, "0")}:${m} ${period}`;
}

// Parse shift string like "08:00 AM - 02:00 PM"
function parseShiftRange(shiftStr?: string): { startHour: number; startMin: number; endHour: number; endMin: number } {
    if (!shiftStr || typeof shiftStr !== "string") {
        return { startHour: 8, startMin: 0, endHour: 14, endMin: 0 };
    }
    const parts = shiftStr.split("-").map(s => s.trim());
    if (parts.length < 2) {
        return { startHour: 8, startMin: 0, endHour: 14, endMin: 0 };
    }
    function parseTimePart(t: string): { h: number; m: number } {
        const match = t.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
        if (!match) return { h: 8, m: 0 };
        let h = parseInt(match[1], 10);
        const m = parseInt(match[2], 10);
        const p = (match[3] || "").toUpperCase();
        if (p === "PM" && h < 12) h += 12;
        if (p === "AM" && h === 12) h = 0;
        return { h, m };
    }
    const s = parseTimePart(parts[0]);
    const e = parseTimePart(parts[1]);
    return { startHour: s.h, startMin: s.m, endHour: e.h, endMin: e.m };
}

// GET /api/doctors/{doctor_id}/availability (Live 30-Minute Slots with 3-Patient Capacity)
export async function getDoctorAvailability(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const doctorId = request.params.doctor_id || "";

    try {
        let doc: any = null;
        let resolvedDoctorId = doctorId;

        if (isValidUuid(doctorId)) {
            const docSql = `
                SELECT u.user_id, u.full_name, sp.availability, sp.specialties
                FROM health.users u
                JOIN health.staff_profiles sp ON u.user_id = sp.user_id
                WHERE u.user_id = $1::uuid AND u.role = 'doctor';
            `;
            const docRes = await query(docSql, [doctorId]);
            if (docRes.rows.length > 0) {
                doc = docRes.rows[0];
            }
        }

        // If not found by exact UUID (e.g. 'doc_1' or legacy ID), resolve to first doctor or fallback
        if (!doc) {
            const fallbackSql = `
                SELECT u.user_id, u.full_name, sp.availability, sp.specialties
                FROM health.users u
                JOIN health.staff_profiles sp ON u.user_id = sp.user_id
                WHERE u.role = 'doctor'
                ORDER BY u.created_at ASC
                LIMIT 1;
            `;
            const fbRes = await query(fallbackSql);
            if (fbRes.rows.length > 0) {
                doc = fbRes.rows[0];
                resolvedDoctorId = doc.user_id;
            } else {
                doc = {
                    user_id: doctorId,
                    full_name: "Consultant Doctor",
                    availability: { shift: "08:00 AM - 02:00 PM", chamber: "Ashwini Central Hospital" },
                    specialties: ["General Physician"],
                };
            }
        }

        const avail = doc.availability || {};
        const shiftStr = avail.shift || "08:00 AM - 02:00 PM";

        const dateParam = request.query.get("date");
        let dateStr: string;
        if (dateParam && /^\d{4}-\d{2}-\d{2}$/.test(dateParam)) {
            dateStr = dateParam;
        } else {
            dateStr = new Date().toISOString().slice(0, 10);
        }

        const shiftTimes = parseShiftRange(shiftStr);
        const slots: Array<{
            slot_time: string;
            time_label: string;
            start_hour: number;
            start_min: number;
            capacity: number;
            booked_count: number;
            remaining_spots: number;
            status: "available" | "fast_filling" | "full";
            is_bookable: boolean;
            is_past: boolean;
        }> = [];

        let curH = shiftTimes.startHour;
        let curM = shiftTimes.startMin;
        const endTotalM = shiftTimes.endHour * 60 + shiftTimes.endMin;

        while (curH * 60 + curM < endTotalM) {
            const period = curH >= 12 ? "PM" : "AM";
            const displayH = curH % 12 === 0 ? 12 : curH % 12;
            const slotLabel = `${displayH.toString().padStart(2, "0")}:${curM.toString().padStart(2, "0")} ${period}`;

            slots.push({
                slot_time: slotLabel,
                time_label: slotLabel,
                start_hour: curH,
                start_min: curM,
                capacity: 3,
                booked_count: 0,
                remaining_spots: 3,
                status: "available",
                is_bookable: true,
                is_past: false,
            });

            curM += 30;
            if (curM >= 60) {
                curH += Math.floor(curM / 60);
                curM = curM % 60;
            }
        }

        // Fetch active appointments for this doctor on this date
        const apptSql = `
            SELECT appointment_id, scheduled_start, status, notes
            FROM health.appointments
            WHERE (provider_user_id::text = $1 OR provider_user_id::text = $2)
              AND status IN ('queued', 'confirmed', 'in_progress')
              AND (
                (scheduled_start AT TIME ZONE 'Asia/Kolkata')::date = $3::date
                OR (scheduled_start AT TIME ZONE 'UTC')::date = $3::date
                OR notes->>'appointment_date' ILIKE $4
              );
        `;
        const apptRes = await query(apptSql, [resolvedDoctorId, doctorId, dateStr, `%${dateStr}%`]);

        const now = new Date();
        const todayStr = now.toISOString().slice(0, 10);
        const isToday = dateStr === todayStr;

        for (const slot of slots) {
            let count = 0;
            for (const a of apptRes.rows) {
                const notes = a.notes || {};
                if (notes.slot_time && notes.slot_time.trim().toLowerCase() === slot.slot_time.toLowerCase()) {
                    count++;
                } else if (a.scheduled_start) {
                    const aDate = new Date(a.scheduled_start);
                    const aH = aDate.getHours();
                    const aM = aDate.getMinutes();
                    if (Math.abs(aH * 60 + aM - (slot.start_hour * 60 + slot.start_min)) < 15) {
                        count++;
                    }
                }
            }

            slot.booked_count = count;
            slot.remaining_spots = Math.max(0, 3 - count);
            if (slot.remaining_spots === 0) {
                slot.status = "full";
            } else if (slot.remaining_spots === 1) {
                slot.status = "fast_filling";
            } else {
                slot.status = "available";
            }

            if (isToday) {
                const currentM = now.getHours() * 60 + now.getMinutes();
                const slotEndM = slot.start_hour * 60 + slot.start_min + 30;
                if (currentM >= slotEndM) {
                    slot.is_past = true;
                }
            }

            slot.is_bookable = slot.remaining_spots > 0 && !slot.is_past;
        }

        return jsonResponse(200, {
            success: true,
            doctor_id: doctorId,
            doctor_name: doc.full_name,
            shift: shiftStr,
            date: dateStr,
            chamber: avail.chamber || "Ashwini Central Hospital",
            total_slots: slots.length,
            available_slots: slots.filter(s => s.is_bookable).length,
            data: slots,
        });
    } catch (err: any) {
        context.error("Error in getDoctorAvailability:", err);
        return errorResponse(500, "Internal server error fetching doctor availability.");
    }
}

// POST /api/appointments/{appointment_id}/telehealth-access (Secure Join Window & Token)
export async function getTelehealthAccess(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }
    const auth = authResult as TokenPayload;

    const appointmentId = request.params.appointment_id;
    if (!isValidUuid(appointmentId)) {
        return errorResponse(400, "Invalid appointment_id format. Must be a valid UUID.");
    }

    try {
        const sql = `
            SELECT 
                a.appointment_id,
                a.patient_id,
                a.provider_user_id,
                a.appointment_type,
                a.scheduled_start,
                a.scheduled_end,
                a.status,
                a.notes,
                pu.full_name AS patient_name,
                du.full_name AS doctor_name
            FROM health.appointments a
            JOIN health.patients p ON a.patient_id = p.patient_id
            JOIN health.users pu ON p.user_id = pu.user_id
            LEFT JOIN health.users du ON a.provider_user_id = du.user_id
            WHERE a.appointment_id = $1::uuid;
        `;
        const result = await query(sql, [appointmentId]);
        if (result.rows.length === 0) {
            return errorResponse(404, `Appointment with ID ${appointmentId} not found.`);
        }

        const appt = result.rows[0];

        // 1. Authorization check
        const isPatient = auth.role === "patient" && auth.patient_id === appt.patient_id;
        const isDoctor = auth.role === "doctor" && auth.user_id === appt.provider_user_id;
        const isAdmin = auth.role === "admin";
        const isWorker = auth.role === "worker" || auth.role === "nurse";

        if (!isPatient && !isDoctor && !isAdmin && !isWorker) {
            return errorResponse(403, "Access denied. You are not authorized to access this consultation.");
        }

        // 2. Validate appointment_type
        const rawType = String(appt.appointment_type).toLowerCase();
        if (rawType !== "telehealth" && rawType !== "online") {
            return errorResponse(400, "This appointment is not scheduled for telehealth/video consultation.");
        }

        // 3. Status checks
        if (appt.status === "completed") {
            return errorResponse(400, "This consultation has already ended.");
        }
        if (appt.status === "cancelled") {
            return errorResponse(400, "This consultation was cancelled.");
        }

        // 4. Join window validation
        const startTime = new Date(appt.scheduled_start).getTime();
        const now = Date.now();
        const fifteenMinutesMs = 15 * 60 * 1000;
        const isTooEarly = now < (startTime - fifteenMinutesMs);

        if (isTooEarly && appt.status !== "in_progress") {
            const minutesLeft = Math.ceil((startTime - fifteenMinutesMs - now) / 60000);
            return errorResponse(
                403,
                `Consultation join window is not open yet. You can join 15 minutes before the scheduled time (in ~${minutesLeft} minutes).`
            );
        }

        // 5. If Doctor joins a confirmed consultation, transition status to 'in_progress'
        let currentStatus = appt.status;
        if (isDoctor && currentStatus === "confirmed") {
            await query(
                `UPDATE health.appointments SET status = 'in_progress', updated_at = NOW() WHERE appointment_id = $1::uuid;`,
                [appointmentId]
            );
            currentStatus = "in_progress";
        }

        return jsonResponse(200, {
            success: true,
            appointment_id: appt.appointment_id,
            room_id: appt.appointment_id,
            status: currentStatus,
            join_allowed: true,
            scheduled_start: appt.scheduled_start,
            doctor_name: appt.doctor_name,
            patient_name: appt.patient_name,
            role_joined: auth.role,
        });
    } catch (err: any) {
        context.error("Error in getTelehealthAccess:", err);
        return errorResponse(500, "Internal server error authorizing telehealth session.");
    }
}

// GET /api/facilities
export async function getFacilities(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

    try {
        const sql = `
            SELECT facility_id, name, facility_type, address, contact_data, operating_hours
            FROM health.facilities
            ORDER BY name ASC;
        `;
        const result = await query(sql);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getFacilities:", err);
        return errorResponse(500, "Internal server error fetching facilities.");
    }
}

app.http("getMyAppointments", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "me/appointments",
    handler: getMyAppointments,
});

app.http("getAppointments", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "appointments",
    handler: getAppointments,
});

app.http("createAppointment", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "appointments",
    handler: createAppointment,
});

app.http("getAppointmentById", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "appointments/{appointment_id}",
    handler: getAppointmentById,
});

app.http("updateAppointment", {
    methods: ["PATCH"],
    authLevel: "anonymous",
    route: "appointments/{appointment_id}",
    handler: updateAppointment,
});

app.http("deleteAppointment", {
    methods: ["DELETE"],
    authLevel: "anonymous",
    route: "appointments/{appointment_id}",
    handler: deleteAppointment,
});

app.http("getDoctorAvailability", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "doctors/{doctor_id}/availability",
    handler: getDoctorAvailability,
});

app.http("getTelehealthAccess", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "appointments/{appointment_id}/telehealth-access",
    handler: getTelehealthAccess,
});

app.http("getFacilities", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "facilities",
    handler: getFacilities,
});

