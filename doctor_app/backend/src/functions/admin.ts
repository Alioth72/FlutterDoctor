import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { pool, query } from "../db";
import { authenticate } from "../utils/auth";
import { TokenPayload } from "../utils/token";
import { normalizePhoneNumber } from "./auth";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";
import { hashPassword, validatePasswordPolicy } from "../utils/password";

// POST /api/staff/doctors (Register Doctor)
export async function createDoctor(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // 1. Authenticate JWT Bearer Token (returns 401 if missing or invalid)
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;

    // 2. Authorize: Verify caller has role = admin (returns 403 for non-admins)
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    // 3. Parse JSON body
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const {
        full_name,
        phone,
        password,
        license_number,
        specialties,
        availability,
        preferred_language = "en",
        date_of_birth,
        sex_at_birth,
        consent,
        profile_data,
    } = body;

    // 4. Validate full_name
    if (!full_name || typeof full_name !== "string" || full_name.trim().length === 0) {
        return errorResponse(400, "Field 'full_name' is required and must be a non-empty string.");
    }

    const trimmedName = full_name.trim();
    const formattedName = trimmedName.startsWith("Dr.") ? trimmedName : `Dr. ${trimmedName}`;

    // 5. Validate and normalize phone
    if (!phone || typeof phone !== "string") {
        return errorResponse(400, "Field 'phone' is required and must be a string.");
    }

    const normalized = normalizePhoneNumber(phone);
    if (!normalized) {
        return errorResponse(400, "Invalid phone number format. Must contain at least 10 valid digits.");
    }

    // 5b. Validate password policy
    const passCheck = validatePasswordPolicy(password);
    if (!passCheck.valid) {
        return errorResponse(400, passCheck.message || "Password is required and must be at least 8 characters in length.");
    }
    const hashedPassword = await hashPassword(password);

    const externalAuthId = `auth|staff|${normalized.localDigits}`;

    // 6. Check for duplicate phone in health.users
    const existingUser = await query(
        "SELECT user_id FROM health.users WHERE phone_e164 = $1 OR phone_e164 = $2 OR external_auth_id = $3 LIMIT 1;",
        [normalized.e164, normalized.localDigits, externalAuthId]
    );
    if (existingUser.rows.length > 0) {
        return errorResponse(409, "A user with this phone number is already registered.");
    }

    // 7. Check for duplicate license_number if provided
    const cleanLicense = license_number && typeof license_number === "string" && license_number.trim().length > 0
        ? license_number.trim()
        : null;

    if (cleanLicense) {
        const existingLicense = await query(
            "SELECT staff_profile_id FROM health.staff_profiles WHERE license_number = $1 LIMIT 1;",
            [cleanLicense]
        );
        if (existingLicense.rows.length > 0) {
            return errorResponse(409, "A staff member with this medical license number is already registered.");
        }
    }

    // Normalize specialties array
    let specialtiesArray: string[] = [];
    if (Array.isArray(specialties)) {
        specialtiesArray = specialties.map((s: any) => String(s).trim()).filter((s: string) => s.length > 0);
    } else if (typeof specialties === "string" && specialties.trim().length > 0) {
        specialtiesArray = [specialties.trim()];
    }

    // Normalize availability object
    const availabilityObj = typeof availability === "object" && availability !== null ? availability : {};

    // 8. Atomic multi-table PostgreSQL transaction
    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        // Insert into health.users with password_hash
        const userSql = `
            INSERT INTO health.users (
                external_auth_id, role, full_name, phone_e164,
                preferred_language, date_of_birth, sex_at_birth,
                consent, profile_data, is_active, password_hash
            ) VALUES ($1, 'doctor', $2, $3, $4, $5, $6, $7, $8, true, $9)
            RETURNING user_id, external_auth_id, role, full_name, phone_e164, is_active, created_at;
        `;
        const userRes = await client.query(userSql, [
            externalAuthId,
            formattedName,
            normalized.e164,
            preferred_language || "en",
            date_of_birth || null,
            sex_at_birth || null,
            JSON.stringify(consent || {}),
            JSON.stringify(profile_data || {}),
            hashedPassword,
        ]);
        const user = userRes.rows[0];

        // Insert into health.staff_profiles
        const staffSql = `
            INSERT INTO health.staff_profiles (
                user_id, staff_type, license_number, specialties, availability
            ) VALUES ($1, 'doctor', $2, $3, $4)
            RETURNING staff_profile_id, staff_type, license_number, specialties, availability, created_at;
        `;
        const staffRes = await client.query(staffSql, [
            user.user_id,
            cleanLicense,
            JSON.stringify(specialtiesArray),
            JSON.stringify(availabilityObj),
        ]);
        const staff = staffRes.rows[0];

        await client.query("COMMIT;");

        context.log(`Successfully created doctor: ${user.full_name} (${user.user_id}) by admin ${authPayload.user_id}`);

        return jsonResponse(201, {
            success: true,
            message: "Doctor created successfully.",
            data: {
                user_id: user.user_id,
                staff_profile_id: staff.staff_profile_id,
                full_name: user.full_name,
                phone_e164: user.phone_e164,
                role: user.role,
                staff_type: staff.staff_type,
                license_number: staff.license_number,
                specialties: staff.specialties,
                availability: staff.availability,
                is_active: user.is_active,
                created_at: user.created_at,
            },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error creating doctor in atomic transaction:", err);
        return errorResponse(500, "Failed to create doctor due to a server error. Transaction rolled back.");
    } finally {
        client.release();
    }
}

// GET /api/staff/doctors (List All Doctors from Database)
export async function getDoctors(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    try {
        const sql = `
            SELECT 
                u.user_id,
                u.external_auth_id,
                u.full_name,
                u.phone_e164,
                u.preferred_language,
                u.is_active,
                u.created_at,
                u.updated_at,
                s.staff_profile_id,
                s.staff_type,
                s.license_number,
                s.specialties,
                s.availability
            FROM health.users u
            JOIN health.staff_profiles s ON u.user_id = s.user_id
            WHERE u.role = 'doctor'
            ORDER BY u.created_at DESC;
        `;

        const result = await query(sql);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error fetching doctors:", err);
        return errorResponse(500, "Internal server error fetching doctors from database.");
    }
}

// PUT /api/staff/doctors/{user_id} (Update Doctor Profile in Database)
export async function updateDoctor(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    const userId = request.params.user_id;
    if (!isValidUuid(userId)) {
        return errorResponse(400, "Invalid doctor user_id format. Must be a valid UUID.");
    }

    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const {
        full_name,
        license_number,
        specialties,
        availability,
        is_active,
    } = body;

    // Check doctor exists
    const doctorCheck = await query(
        "SELECT u.user_id, u.full_name, s.staff_profile_id FROM health.users u JOIN health.staff_profiles s ON u.user_id = s.user_id WHERE u.user_id = $1 AND u.role = 'doctor';",
        [userId]
    );
    if (doctorCheck.rows.length === 0) {
        return errorResponse(404, `Doctor with ID ${userId} not found.`);
    }

    // Duplicate license check if license_number is updated
    if (license_number !== undefined && license_number !== null) {
        const cleanLicense = String(license_number).trim();
        if (cleanLicense.length > 0) {
            const licenseCheck = await query(
                "SELECT staff_profile_id FROM health.staff_profiles WHERE license_number = $1 AND user_id != $2 LIMIT 1;",
                [cleanLicense, userId]
            );
            if (licenseCheck.rows.length > 0) {
                return errorResponse(409, "Another staff member is already registered with this medical license number.");
            }
        }
    }

    let formattedName: string | null = null;
    if (full_name !== undefined && full_name !== null) {
        const trimmed = String(full_name).trim();
        if (trimmed.length > 0) {
            formattedName = trimmed.startsWith("Dr.") ? trimmed : `Dr. ${trimmed}`;
        }
    }

    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        // Update health.users
        const userUpdateSql = `
            UPDATE health.users
            SET 
                full_name = COALESCE($1, full_name),
                is_active = COALESCE($2, is_active),
                updated_at = now()
            WHERE user_id = $3
            RETURNING user_id, external_auth_id, role, full_name, phone_e164, is_active, updated_at;
        `;
        const userRes = await client.query(userUpdateSql, [
            formattedName,
            is_active !== undefined ? Boolean(is_active) : null,
            userId,
        ]);
        const user = userRes.rows[0];

        // Format specialties and availability
        let specialtiesJson: string | null = null;
        if (specialties !== undefined && specialties !== null) {
            const arr = Array.isArray(specialties)
                ? specialties.map((s: any) => String(s).trim()).filter(Boolean)
                : [String(specialties).trim()];
            specialtiesJson = JSON.stringify(arr);
        }

        let availabilityJson: string | null = null;
        if (availability !== undefined && availability !== null && typeof availability === "object") {
            availabilityJson = JSON.stringify(availability);
        }

        const cleanLicense = license_number !== undefined
            ? (license_number ? String(license_number).trim() : null)
            : null;

        // Update health.staff_profiles
        const staffUpdateSql = `
            UPDATE health.staff_profiles
            SET 
                license_number = CASE WHEN $1::boolean THEN $2 ELSE license_number END,
                specialties = COALESCE($3::jsonb, specialties),
                availability = COALESCE($4::jsonb, availability),
                updated_at = now()
            WHERE user_id = $5
            RETURNING staff_profile_id, staff_type, license_number, specialties, availability, updated_at;
        `;
        const staffRes = await client.query(staffUpdateSql, [
            license_number !== undefined,
            cleanLicense,
            specialtiesJson,
            availabilityJson,
            userId,
        ]);
        const staff = staffRes.rows[0];

        await client.query("COMMIT;");

        context.log(`Admin ${authPayload.user_id} updated doctor: ${user.full_name} (${userId})`);

        return jsonResponse(200, {
            success: true,
            message: "Doctor profile updated successfully.",
            data: {
                user_id: user.user_id,
                staff_profile_id: staff.staff_profile_id,
                full_name: user.full_name,
                phone_e164: user.phone_e164,
                role: user.role,
                staff_type: staff.staff_type,
                license_number: staff.license_number,
                specialties: staff.specialties,
                availability: staff.availability,
                is_active: user.is_active,
                updated_at: user.updated_at,
            },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error updating doctor in transaction:", err);
        return errorResponse(500, `Failed to update doctor: ${err.message}`);
    } finally {
        client.release();
    }
}

// POST /api/staff/patients (Register Patient)
export async function createPatient(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // 1. Authenticate JWT Bearer Token
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;

    // 2. Authorize: Admin only
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    // 3. Parse JSON body
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const {
        full_name,
        phone,
        date_of_birth,
        sex_at_birth = "male",
        preferred_language = "en",
        blood_group,
        medical_record_number,
        allergies = [],
        emergency_contact = {},
        disability_data = {},
        profile_data = {},
    } = body;

    // 4. Validate full_name
    if (!full_name || typeof full_name !== "string" || full_name.trim().length === 0) {
        return errorResponse(400, "Field 'full_name' is required and must be a non-empty string.");
    }

    // 5. Validate and normalize phone
    if (!phone || typeof phone !== "string") {
        return errorResponse(400, "Field 'phone' is required and must be a string.");
    }

    const normalized = normalizePhoneNumber(phone);
    if (!normalized) {
        return errorResponse(400, "Invalid phone number format. Must contain at least 10 valid digits.");
    }
    const normalizedPhone = normalized.e164;

    // 6. Check duplicate phone
    const existingUser = await query("SELECT user_id FROM health.users WHERE phone_e164 = $1", [normalizedPhone]);
    if (existingUser.rows.length > 0) {
        return errorResponse(409, `A user with phone number ${normalizedPhone} already exists.`);
    }

    // 7. Auto-generate MRN if not provided
    let mrn = typeof medical_record_number === "string" && medical_record_number.trim().length > 0
        ? medical_record_number.trim()
        : `MRN-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;

    const existingMrn = await query("SELECT patient_id FROM health.patients WHERE medical_record_number = $1", [mrn]);
    if (existingMrn.rows.length > 0) {
        mrn = `MRN-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;
    }

    // 7b. Password setup
    let rawPassword = body.password;
    if (rawPassword) {
        const passCheck = validatePasswordPolicy(rawPassword);
        if (!passCheck.valid) {
            return errorResponse(400, passCheck.message || "Invalid password.");
        }
    } else {
        rawPassword = "Patient@12345";
    }
    const hashedPassword = await hashPassword(rawPassword);

    // 8. Atomic transaction
    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        const externalAuthId = `auth|patient|${normalizedPhone.replace(/\+/g, "")}`;

        const userInsertSql = `
            INSERT INTO health.users (
                external_auth_id,
                role,
                full_name,
                phone_e164,
                preferred_language,
                date_of_birth,
                sex_at_birth,
                consent,
                profile_data,
                is_active,
                password_hash
            ) VALUES ($1, 'patient', $2, $3, $4, $5, $6, $7, $8, true, $9)
            RETURNING user_id, full_name, phone_e164, role, preferred_language, date_of_birth, sex_at_birth, is_active, created_at;
        `;

        const userRes = await client.query(userInsertSql, [
            externalAuthId,
            full_name.trim(),
            normalizedPhone,
            preferred_language,
            date_of_birth || null,
            sex_at_birth ? sex_at_birth.toLowerCase() : null,
            JSON.stringify({ termsAccepted: true, timestamp: new Date().toISOString() }),
            JSON.stringify(profile_data),
            hashedPassword,
        ]);
        const newUser = userRes.rows[0];

        const patientInsertSql = `
            INSERT INTO health.patients (
                user_id,
                medical_record_number,
                blood_group,
                allergies,
                emergency_contact,
                disability_data
            ) VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING patient_id, user_id, medical_record_number, blood_group, allergies, emergency_contact, disability_data, created_at;
        `;

        const patientRes = await client.query(patientInsertSql, [
            newUser.user_id,
            mrn,
            blood_group || null,
            JSON.stringify(Array.isArray(allergies) ? allergies : []),
            JSON.stringify(emergency_contact),
            JSON.stringify(disability_data),
        ]);
        const newPatient = patientRes.rows[0];

        // 9. Optional Initial Doctor Assignment in the same transaction
        let initialAppt: any = null;
        const initialDoctorId = body.doctor_user_id || body.assigned_doctor_id || body.initial_doctor_user_id;
        if (initialDoctorId) {
            if (!isValidUuid(initialDoctorId)) {
                await client.query("ROLLBACK;");
                return errorResponse(400, "Invalid doctor_user_id format. Must be a valid UUID.");
            }
            const docCheck = await client.query(
                `SELECT user_id, full_name FROM health.users WHERE user_id = $1::uuid AND role = 'doctor'`,
                [initialDoctorId]
            );
            if (docCheck.rows.length === 0) {
                await client.query("ROLLBACK;");
                return errorResponse(404, `Doctor with ID ${initialDoctorId} not found.`);
            }

            const aptNo = await generateUniqueAppointmentNo(client);
            const apptInsertSql = `
                INSERT INTO health.appointments (
                    patient_id, provider_user_id, appointment_type, scheduled_start,
                    status, reason, source, notes
                ) VALUES (
                    $1::uuid, $2::uuid, 'clinic', NOW(),
                    'confirmed', $3, 'online', $4::jsonb
                ) RETURNING *;
            `;
            const apptRes = await client.query(apptInsertSql, [
                newPatient.patient_id,
                initialDoctorId,
                body.reason || "Initial Intake Consultation",
                JSON.stringify({
                    appointment_no: aptNo,
                    payment_status: "Paid Online (₹500)",
                    is_paid: true,
                }),
            ]);
            initialAppt = apptRes.rows[0];
        }

        await client.query("COMMIT;");
        context.log(`Admin ${authPayload.user_id} created patient: ${newUser.full_name} (${newPatient.patient_id})`);

        return jsonResponse(201, {
            success: true,
            message: initialAppt
                ? "Patient registered and initial consultation scheduled successfully."
                : "Patient registered successfully.",
            data: {
                patient_id: newPatient.patient_id,
                user_id: newUser.user_id,
                full_name: newUser.full_name,
                phone_e164: newUser.phone_e164,
                medical_record_number: newPatient.medical_record_number,
                blood_group: newPatient.blood_group,
                date_of_birth: newUser.date_of_birth,
                sex_at_birth: newUser.sex_at_birth,
                allergies: newPatient.allergies,
                emergency_contact: newPatient.emergency_contact,
                created_at: newPatient.created_at,
                appointment: initialAppt ? {
                    appointment_id: initialAppt.appointment_id,
                    status: initialAppt.status,
                    provider_user_id: initialAppt.provider_user_id,
                    scheduled_start: initialAppt.scheduled_start,
                    appointment_no: (initialAppt.notes as any)?.appointment_no,
                } : null,
            },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error creating patient in transaction:", err);
        return errorResponse(500, `Failed to register patient: ${err.message}`);
    } finally {
        client.release();
    }
}

// DELETE /api/staff/patients/{patient_id}
export async function deletePatient(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    const patientId = request.params.patient_id;
    if (!isValidUuid(patientId)) {
        return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
    }

    const patientRes = await query("SELECT patient_id, user_id FROM health.patients WHERE patient_id = $1::uuid", [patientId]);
    if (patientRes.rows.length === 0) {
        return errorResponse(404, `Patient with ID ${patientId} not found.`);
    }
    const userId = patientRes.rows[0].user_id;

    const client = await pool.connect();
    try {
        await client.query("BEGIN;");
        await client.query("DELETE FROM health.prescriptions WHERE patient_id = $1::uuid;", [patientId]);
        await client.query("DELETE FROM health.medical_records WHERE patient_id = $1::uuid;", [patientId]);
        await client.query("DELETE FROM health.appointments WHERE patient_id = $1::uuid;", [patientId]);
        await client.query("DELETE FROM health.patients WHERE patient_id = $1::uuid;", [patientId]);
        await client.query("DELETE FROM health.users WHERE user_id = $1::uuid;", [userId]);
        await client.query("COMMIT;");

        context.log(`Admin ${authPayload.user_id} deleted patient ${patientId}`);
        return jsonResponse(200, {
            success: true,
            message: "Patient removed successfully.",
            data: { patient_id: patientId, user_id: userId },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error deleting patient in transaction:", err);
        return errorResponse(500, `Failed to delete patient: ${err.message}`);
    } finally {
        client.release();
    }
}

// DELETE /api/staff/doctors/{user_id}
export async function deleteDoctor(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    const userId = request.params.user_id;
    if (!isValidUuid(userId)) {
        return errorResponse(400, "Invalid user_id format. Must be a valid UUID.");
    }

    const docRes = await query("SELECT user_id, full_name FROM health.users WHERE user_id = $1::uuid AND role = 'doctor'", [userId]);
    if (docRes.rows.length === 0) {
        return errorResponse(404, `Doctor with ID ${userId} not found.`);
    }
    const doctorName = docRes.rows[0].full_name;

    const client = await pool.connect();
    try {
        await client.query("BEGIN;");
        await client.query("DELETE FROM health.appointments WHERE provider_user_id = $1::uuid;", [userId]);
        await client.query("DELETE FROM health.staff_profiles WHERE user_id = $1::uuid;", [userId]);
        await client.query("DELETE FROM health.users WHERE user_id = $1::uuid;", [userId]);
        await client.query("COMMIT;");

        context.log(`Admin ${authPayload.user_id} deleted doctor: ${doctorName} (${userId})`);
        return jsonResponse(200, {
            success: true,
            message: `Doctor ${doctorName} removed successfully from database.`,
            data: { user_id: userId, full_name: doctorName },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error deleting doctor in transaction:", err);
        return errorResponse(500, `Failed to delete doctor: ${err.message}`);
    } finally {
        client.release();
    }
}

async function generateUniqueAppointmentNo(client: any): Promise<string> {
    for (let i = 0; i < 30; i++) {
        const num = Math.floor(100 + Math.random() * 900);
        const candidate = `APT-${num}`;
        const check = await client.query(
            `SELECT 1 FROM health.appointments WHERE notes->>'appointment_no' = $1 LIMIT 1;`,
            [candidate]
        );
        if (check.rows.length === 0) {
            return candidate;
        }
    }
    return `APT-${Date.now().toString().slice(-4)}`;
}

// POST /api/admin/assign-patient (Admin Assign/Reassign Patient to Doctor)
export async function assignPatientDoctor(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    // 1. Authenticate JWT Bearer Token
    const authResult = authenticate(request);
    if ("status" in authResult) {
        return authResult;
    }

    const authPayload = authResult as TokenPayload;
    if (authPayload.role !== "admin") {
        return errorResponse(403, "Access denied. Administrator privileges required.");
    }

    // 2. Parse JSON body
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const { patient_id, doctor_user_id, appointment_type = "clinic", reason } = body;

    if (!isValidUuid(patient_id)) {
        return errorResponse(400, "Invalid patient_id format. Must be a valid UUID.");
    }
    if (!isValidUuid(doctor_user_id)) {
        return errorResponse(400, "Invalid doctor_user_id format. Must be a valid UUID.");
    }

    // 3. Connect client and begin transaction with row locking
    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        // Lock the patient row for update so concurrent assignment requests serialize
        const patientCheck = await client.query(
            `SELECT p.patient_id, u.full_name as patient_name, p.medical_record_number 
             FROM health.patients p 
             JOIN health.users u ON p.user_id = u.user_id 
             WHERE p.patient_id = $1::uuid
             FOR UPDATE;`,
            [patient_id]
        );
        if (patientCheck.rows.length === 0) {
            await client.query("ROLLBACK;");
            return errorResponse(404, `Patient with ID ${patient_id} not found.`);
        }
        const patient = patientCheck.rows[0];

        // 4. Verify doctor exists and has role 'doctor'
        const doctorCheck = await client.query(
            `SELECT user_id, full_name, role 
             FROM health.users 
             WHERE user_id = $1::uuid AND role = 'doctor';`,
            [doctor_user_id]
        );
        if (doctorCheck.rows.length === 0) {
            await client.query("ROLLBACK;");
            return errorResponse(404, `Doctor with ID ${doctor_user_id} not found.`);
        }
        const doctor = doctorCheck.rows[0];

        // 5. Check if patient currently has an in_progress appointment
        const inProgressCheck = await client.query(
            `SELECT a.appointment_id, a.provider_user_id, doc.full_name as doctor_name
             FROM health.appointments a
             LEFT JOIN health.users doc ON a.provider_user_id = doc.user_id
             WHERE a.patient_id = $1::uuid AND a.status = 'in_progress'
             LIMIT 1;`,
            [patient_id]
        );
        if (inProgressCheck.rows.length > 0) {
            await client.query("ROLLBACK;");
            const activeDocName = inProgressCheck.rows[0].doctor_name || "the doctor";
            return jsonResponse(409, {
                success: false,
                error: `Patient currently has an active consultation in progress with Dr. ${activeDocName}. Please wait for the current consultation to complete before assigning or scheduling a new appointment.`,
            });
        }

        // 6. Check if patient has an active uncompleted appointment ('queued' or 'confirmed')
        const activeApptResult = await client.query(
            `SELECT a.appointment_id, a.status, a.notes, a.provider_user_id 
             FROM health.appointments a 
             WHERE a.patient_id = $1::uuid 
               AND a.status IN ('queued', 'confirmed')
             ORDER BY a.scheduled_start DESC 
             LIMIT 1
             FOR UPDATE;`,
            [patient_id]
        );

        let resultAppt: any;
        let actionTaken: string;

        if (activeApptResult.rows.length > 0) {
            // Reassign the existing active queued/confirmed appointment
            const currentAppt = activeApptResult.rows[0];
            const updated = await client.query(
                `UPDATE health.appointments
                 SET provider_user_id = $1::uuid,
                     reason = COALESCE($2, reason),
                     updated_at = NOW()
                 WHERE appointment_id = $3::uuid
                 RETURNING *;`,
                [doctor_user_id, reason || null, currentAppt.appointment_id]
            );
            resultAppt = updated.rows[0];
            actionTaken = "reassigned";
        } else {
            // No active queued/confirmed appointment exists.
            // (Patient has either never had an appointment, or all previous appointments are 'completed', 'cancelled', or 'no_show')
            // INSERT a brand new appointment with status = 'confirmed'
            const aptNo = await generateUniqueAppointmentNo(client);
            const inserted = await client.query(
                `INSERT INTO health.appointments (
                    patient_id, provider_user_id, appointment_type, scheduled_start,
                    status, reason, source, notes
                 ) VALUES (
                    $1::uuid, $2::uuid, $3, NOW(),
                    'confirmed', $4, 'online', $5::jsonb
                 ) RETURNING *;`,
                [
                    patient_id,
                    doctor_user_id,
                    appointment_type,
                    reason || "Doctor Assignment Consultation",
                    JSON.stringify({
                        appointment_no: aptNo,
                        payment_status: "Paid Online (₹500)",
                        is_paid: true,
                    }),
                ]
            );
            resultAppt = inserted.rows[0];
            actionTaken = "created";
        }

        await client.query("COMMIT;");

        return jsonResponse(200, {
            success: true,
            action: actionTaken,
            message: actionTaken === "created"
                ? `New consultation created for ${patient.patient_name} with Dr. ${doctor.full_name}.`
                : `Active consultation for ${patient.patient_name} reassigned to Dr. ${doctor.full_name}.`,
            data: {
                patient_id,
                patient_name: patient.patient_name,
                doctor_user_id,
                doctor_name: doctor.full_name,
                appointment_id: resultAppt.appointment_id,
                status: resultAppt.status,
                action: actionTaken,
            },
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error in assignPatientDoctor:", err);
        return errorResponse(500, `Failed to assign patient to doctor: ${err.message}`);
    } finally {
        client.release();
    }
}

// Route Bindings
app.http("manageDoctors", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "staff/doctors",
    handler: createDoctor,
});

app.http("getStaffDoctors", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "staff/doctors",
    handler: getDoctors,
});

app.http("updateStaffDoctor", {
    methods: ["PUT", "PATCH"],
    authLevel: "anonymous",
    route: "staff/doctors/{user_id}",
    handler: updateDoctor,
});

app.http("deleteStaffDoctor", {
    methods: ["DELETE"],
    authLevel: "anonymous",
    route: "staff/doctors/{user_id}",
    handler: deleteDoctor,
});

app.http("managePatients", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "staff/patients",
    handler: createPatient,
});

app.http("deletePatient", {
    methods: ["DELETE"],
    authLevel: "anonymous",
    route: "staff/patients/{patient_id}",
    handler: deletePatient,
});

app.http("assignPatientDoctor", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "staff/assign-patient",
    handler: assignPatientDoctor,
});



