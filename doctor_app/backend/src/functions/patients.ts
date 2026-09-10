import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query } from "../db";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";
import { authenticate } from "../utils/auth";

// GET /api/patients
export async function getPatients(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

    try {
        const search = request.query.get("search") || null;

        const sql = `
            SELECT 
                p.patient_id,
                p.user_id,
                u.full_name,
                u.phone_e164,
                u.date_of_birth,
                u.sex_at_birth,
                u.preferred_language,
                p.medical_record_number,
                p.blood_group,
                p.allergies,
                p.emergency_contact,
                p.disability_data,
                p.created_at,
                p.updated_at,
                latest_appt.appointment_id,
                latest_appt.status AS latest_appointment_status,
                latest_appt.provider_user_id AS assigned_doctor_user_id,
                doc_u.full_name AS assigned_doctor_name
            FROM health.patients p
            JOIN health.users u ON p.user_id = u.user_id
            LEFT JOIN LATERAL (
                SELECT a.appointment_id, a.provider_user_id, a.status
                FROM health.appointments a
                WHERE a.patient_id = p.patient_id
                ORDER BY 
                    CASE 
                        WHEN a.status = 'in_progress' THEN 1
                        WHEN a.status = 'confirmed' THEN 2
                        WHEN a.status = 'queued' THEN 3
                        ELSE 4
                    END ASC,
                    a.scheduled_start DESC,
                    a.created_at DESC
                LIMIT 1
            ) latest_appt ON true
            LEFT JOIN health.users doc_u ON latest_appt.provider_user_id = doc_u.user_id
            WHERE ($1::text IS NULL OR 
                   u.full_name ILIKE '%' || $1 || '%' OR 
                   u.phone_e164 ILIKE '%' || $1 || '%' OR 
                   p.medical_record_number ILIKE '%' || $1 || '%')
            ORDER BY u.full_name ASC;
        `;

        const result = await query(sql, [search]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getPatients:", err);
        return errorResponse(500, "Internal server error fetching patients.");
    }
}

// GET /api/patients/{patient_id}
export async function getPatientById(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

    try {
        const patientId = request.params.patient_id;

        if (!isValidUuid(patientId)) {
            return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
        }

        const sql = `
            SELECT 
                p.patient_id,
                p.user_id,
                u.full_name,
                u.phone_e164,
                u.date_of_birth,
                u.sex_at_birth,
                u.preferred_language,
                p.medical_record_number,
                p.blood_group,
                p.allergies,
                p.emergency_contact,
                p.disability_data,
                p.created_at,
                p.updated_at
            FROM health.patients p
            JOIN health.users u ON p.user_id = u.user_id
            WHERE p.patient_id = $1::uuid;
        `;

        const result = await query(sql, [patientId]);
        if (result.rows.length === 0) {
            return errorResponse(404, `Patient with ID ${patientId} not found.`);
        }

        return jsonResponse(200, {
            success: true,
            data: result.rows[0],
        });
    } catch (err: any) {
        context.error("Error in getPatientById:", err);
        return errorResponse(500, "Internal server error fetching patient.");
    }
}

// GET /api/patients/{patient_id}/records (Protected Medical Data)
export async function getPatientRecords(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

    try {
        const patientId = request.params.patient_id;

        if (!isValidUuid(patientId)) {
            return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
        }

        // Verify patient exists first
        const patientCheck = await query("SELECT patient_id FROM health.patients WHERE patient_id = $1::uuid", [patientId]);
        if (patientCheck.rows.length === 0) {
            return errorResponse(404, `Patient with ID ${patientId} not found.`);
        }

        const sql = `
            SELECT 
                mr.medical_record_id,
                mr.patient_id,
                mr.author_user_id,
                au.full_name AS author_name,
                mr.appointment_id,
                mr.record_type,
                mr.recorded_at,
                mr.diagnosis,
                mr.symptoms,
                mr.clinical_data,
                mr.confidence,
                mr.is_preliminary,
                mr.created_at
            FROM health.medical_records mr
            LEFT JOIN health.users au ON mr.author_user_id = au.user_id
            WHERE mr.patient_id = $1::uuid
            ORDER BY mr.recorded_at DESC;
        `;

        const result = await query(sql, [patientId]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getPatientRecords:", err);
        return errorResponse(500, "Internal server error fetching patient records.");
    }
}

// GET /api/patients/{patient_id}/prescriptions (Protected Medical Data)
export async function getPatientPrescriptions(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const auth = authenticate(request);
    if ("status" in auth) {
        return auth;
    }

    try {
        const patientId = request.params.patient_id;

        if (!isValidUuid(patientId)) {
            return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
        }

        // Verify patient exists first
        const patientCheck = await query("SELECT patient_id FROM health.patients WHERE patient_id = $1::uuid", [patientId]);
        if (patientCheck.rows.length === 0) {
            return errorResponse(404, `Patient with ID ${patientId} not found.`);
        }

        const sql = `
            SELECT 
                rx.prescription_id,
                rx.patient_id,
                rx.prescriber_user_id,
                doc.full_name AS prescriber_name,
                rx.appointment_id,
                rx.pharmacy_facility_id,
                f.name AS pharmacy_name,
                rx.medication_name,
                rx.dosage,
                rx.route,
                rx.frequency,
                rx.duration_days,
                rx.instructions,
                rx.status,
                rx.created_at,
                rx.updated_at
            FROM health.prescriptions rx
            LEFT JOIN health.users doc ON rx.prescriber_user_id = doc.user_id
            LEFT JOIN health.facilities f ON rx.pharmacy_facility_id = f.facility_id
            WHERE rx.patient_id = $1::uuid
            ORDER BY rx.created_at DESC;
        `;

        const result = await query(sql, [patientId]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getPatientPrescriptions:", err);
        return errorResponse(500, "Internal server error fetching patient prescriptions.");
    }
}

app.http("getPatients", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "patients",
    handler: getPatients,
});

app.http("getPatientById", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "patients/{patient_id}",
    handler: getPatientById,
});

app.http("getPatientRecords", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "patients/{patient_id}/records",
    handler: getPatientRecords,
});

app.http("getPatientPrescriptions", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "patients/{patient_id}/prescriptions",
    handler: getPatientPrescriptions,
});
