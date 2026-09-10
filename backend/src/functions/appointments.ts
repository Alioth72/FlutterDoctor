import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query, pool } from "../db";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";
import { authenticate } from "../utils/auth";

// GET /api/appointments
export async function getAppointments(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

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

        const result = await query(sql, [status, providerUserId, patientId]);
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
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

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

        return jsonResponse(200, {
            success: true,
            data: result.rows[0],
        });
    } catch (err: any) {
        context.error("Error in getAppointmentById:", err);
        return errorResponse(500, "Internal server error fetching appointment.");
    }
}

import { TokenPayload } from "../utils/token";

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

app.http("getAppointments", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "appointments",
    handler: getAppointments,
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
