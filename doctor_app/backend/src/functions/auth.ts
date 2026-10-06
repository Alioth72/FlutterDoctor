import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { pool, query } from "../db";
import { generateToken } from "../utils/token";
import { jsonResponse, errorResponse } from "../utils";
import { hashPassword, verifyPassword, dummyVerify, validatePasswordPolicy } from "../utils/password";

const ALLOWED_ROLES = ["patient", "doctor", "nurse", "volunteer", "pharmacist", "admin", "family_member"];

export function normalizePhoneNumber(rawPhone: string): { e164: string; localDigits: string } | null {
    if (!rawPhone || typeof rawPhone !== "string") return null;

    const trimmed = rawPhone.trim();
    // Remove all characters except leading '+' and digits
    const digitsOnly = trimmed.replace(/\D/g, "");

    if (digitsOnly.length < 10) return null;

    let e164 = "";
    let localDigits = "";

    if (digitsOnly.length === 10) {
        // Assume India (+91) default if 10 digits provided
        e164 = `+91${digitsOnly}`;
        localDigits = digitsOnly;
    } else if (digitsOnly.length === 12 && digitsOnly.startsWith("91")) {
        e164 = `+${digitsOnly}`;
        localDigits = digitsOnly.substring(2);
    } else if (trimmed.startsWith("+")) {
        e164 = `+${digitsOnly}`;
        localDigits = digitsOnly.slice(-10);
    } else {
        e164 = `+${digitsOnly}`;
        localDigits = digitsOnly.slice(-10);
    }

    return { e164, localDigits };
}

// POST /api/auth/signup
export async function signup(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const {
        phone,
        password,
        full_name,
        role = "patient",
        date_of_birth,
        sex_at_birth,
        preferred_language = "en",
        blood_group,
        allergies,
        emergency_contact,
        disability_data,
        license_number,
        specialties,
        availability,
    } = body;

    // 1. Validate required fields
    if (!phone || typeof phone !== "string") {
        return errorResponse(400, "Field 'phone' is required and must be a string.");
    }
    if (!full_name || typeof full_name !== "string" || full_name.trim().length === 0) {
        return errorResponse(400, "Field 'full_name' is required and must be a non-empty string.");
    }

    let rawPassword = password;
    if (rawPassword) {
        const passCheck = validatePasswordPolicy(rawPassword);
        if (!passCheck.valid) {
            return errorResponse(400, passCheck.message || "Invalid password.");
        }
    } else {
        // Default secure temporary password for role
        rawPassword = role === "doctor" ? "Doctor@12345" : (role === "admin" ? "Admin@12345" : "Patient@12345");
    }
    const hashedPassword = await hashPassword(rawPassword);

    // 2. Normalize phone
    const normalized = normalizePhoneNumber(phone);
    if (!normalized) {
        return errorResponse(400, "Invalid phone number. Must contain at least 10 valid digits.");
    }

    // 3. Validate role
    const normalizedRole = (role || "").toLowerCase().trim();
    if (!ALLOWED_ROLES.includes(normalizedRole)) {
        return errorResponse(400, `Invalid role '${role}'. Allowed roles: ${ALLOWED_ROLES.join(", ")}`);
    }

    // 4. Check whether phone already exists
    const existingUser = await query(
        "SELECT user_id FROM health.users WHERE phone_e164 = $1 OR phone_e164 = $2 LIMIT 1;",
        [normalized.e164, normalized.localDigits]
    );
    if (existingUser.rows.length > 0) {
        return errorResponse(409, "A user with this phone number is already registered.");
    }

    // 5. Generate external_auth_id following existing convention
    const prefix = ["doctor", "nurse", "volunteer", "pharmacist", "admin"].includes(normalizedRole)
        ? "staff"
        : normalizedRole;
    const externalAuthId = `auth|${prefix}|${normalized.localDigits}`;

    // 6. Multi-table atomic PostgreSQL transaction
    const client = await pool.connect();
    try {
        await client.query("BEGIN;");

        // Insert health.users with password_hash
        const userSql = `
            INSERT INTO health.users (
                external_auth_id, role, full_name, phone_e164,
                preferred_language, date_of_birth, sex_at_birth,
                consent, profile_data, is_active, password_hash
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, $10)
            RETURNING user_id, external_auth_id, role, full_name, phone_e164;
        `;
        const userRes = await client.query(userSql, [
            externalAuthId,
            normalizedRole,
            full_name.trim(),
            normalized.e164,
            preferred_language || "en",
            date_of_birth || null,
            sex_at_birth || null,
            JSON.stringify(body.consent || {}),
            JSON.stringify(body.profile_data || {}),
            hashedPassword,
        ]);
        const user = userRes.rows[0];

        let patientId: string | null = null;
        let staffProfileId: string | null = null;

        // 7. If patient, create health.patients row with standardized 14-digit Health ID
        if (normalizedRole === "patient") {
            const p1 = Math.floor(1000 + Math.random() * 9000);
            const p2 = Math.floor(1000 + Math.random() * 9000);
            const p3 = Math.floor(1000 + Math.random() * 9000);
            const mrn = `14-${p1}-${p2}-${p3}`;

            const patientSql = `
                INSERT INTO health.patients (
                    user_id, medical_record_number, blood_group,
                    allergies, emergency_contact, disability_data
                ) VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING patient_id;
            `;
            const patRes = await client.query(patientSql, [
                user.user_id,
                mrn,
                blood_group || null,
                JSON.stringify(allergies || []),
                JSON.stringify(emergency_contact || {}),
                JSON.stringify(disability_data || {}),
            ]);
            patientId = patRes.rows[0].patient_id;
        } else if (["doctor", "nurse", "volunteer", "pharmacist", "admin"].includes(normalizedRole)) {
            // 8. If staff, create health.staff_profiles row with recognized NMC Reg No for doctors
            let effectiveLicense = license_number;
            if (normalizedRole === "doctor" && (!effectiveLicense || effectiveLicense.trim().length === 0)) {
                effectiveLicense = `NMC-${new Date().getFullYear()}-${Math.floor(100000 + Math.random() * 900000)}`;
            }

            const staffSql = `
                INSERT INTO health.staff_profiles (
                    user_id, staff_type, license_number, specialties, availability
                ) VALUES ($1, $2, $3, $4, $5)
                RETURNING staff_profile_id;
            `;
            const staffRes = await client.query(staffSql, [
                user.user_id,
                normalizedRole,
                effectiveLicense || null,
                JSON.stringify(specialties || []),
                JSON.stringify(availability || {}),
            ]);
            staffProfileId = staffRes.rows[0].staff_profile_id;
        }

        await client.query("COMMIT;");

        // 9. Generate token
        const token = generateToken({
            user_id: user.user_id,
            patient_id: patientId,
            staff_profile_id: staffProfileId,
            external_auth_id: user.external_auth_id,
            role: user.role,
            full_name: user.full_name,
            phone_e164: user.phone_e164,
        });

        return jsonResponse(201, {
            success: true,
            data: {
                user_id: user.user_id,
                patient_id: patientId,
                staff_profile_id: staffProfileId,
                external_auth_id: user.external_auth_id,
                role: user.role,
                full_name: user.full_name,
                phone_e164: user.phone_e164,
            },
            token,
        });
    } catch (err: any) {
        await client.query("ROLLBACK;");
        context.error("Error during signup transaction:", err);
        return errorResponse(500, "Account creation failed due to a server error. Please try again.");
    } finally {
        client.release();
    }
}

// POST /api/auth/login
export async function login(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    let body: any = {};
    try {
        body = await request.json();
    } catch {
        return errorResponse(400, "Invalid JSON payload in request body.");
    }

    const { phone, password } = body;
    if (!phone || typeof phone !== "string") {
        return errorResponse(400, "Field 'phone' is required and must be a string.");
    }
    if (!password || typeof password !== "string" || password.trim().length === 0) {
        return errorResponse(400, "Field 'password' is required and must be a non-empty string.");
    }

    const normalized = normalizePhoneNumber(phone);
    if (!normalized) {
        return errorResponse(400, "Invalid phone number format.");
    }

    try {
        const sql = `
            SELECT 
                u.user_id, u.external_auth_id, u.role, u.full_name, u.phone_e164,
                u.preferred_language, u.date_of_birth, u.sex_at_birth, u.is_active, u.profile_data,
                u.password_hash,
                p.patient_id, p.medical_record_number, p.blood_group,
                s.staff_profile_id, s.staff_type, s.license_number, s.specialties, s.availability
            FROM health.users u
            LEFT JOIN health.patients p ON u.user_id = p.user_id
            LEFT JOIN health.staff_profiles s ON u.user_id = s.user_id
            WHERE u.phone_e164 = $1 OR u.phone_e164 = $2 OR u.external_auth_id LIKE '%' || $2
            LIMIT 1;
        `;

        const result = await query(sql, [normalized.e164, normalized.localDigits]);
        if (result.rows.length === 0) {
            // Mitigate timing attack with dummy hash verification
            await dummyVerify(password);
            return errorResponse(401, "Invalid phone number or password.");
        }

        const user = result.rows[0];

        // Verify active status
        if (!user.is_active) {
            return errorResponse(403, "This account has been deactivated. Please contact your health administrator.");
        }

        // Verify password against stored bcrypt hash
        if (!user.password_hash) {
            await dummyVerify(password);
            return errorResponse(401, "Invalid phone number or password.");
        }

        const passwordMatches = await verifyPassword(password, user.password_hash);
        if (!passwordMatches) {
            return errorResponse(401, "Invalid phone number or password.");
        }

        // Generate signed JWT token
        const token = generateToken({
            user_id: user.user_id,
            patient_id: user.patient_id || null,
            staff_profile_id: user.staff_profile_id || null,
            external_auth_id: user.external_auth_id,
            role: user.role,
            full_name: user.full_name,
            phone_e164: user.phone_e164,
        });

        return jsonResponse(200, {
            success: true,
            data: {
                user_id: user.user_id,
                patient_id: user.patient_id || null,
                staff_profile_id: user.staff_profile_id || null,
                external_auth_id: user.external_auth_id,
                role: user.role,
                full_name: user.full_name,
                phone_e164: user.phone_e164,
                medical_record_number: user.medical_record_number || null,
                blood_group: user.blood_group || null,
                license_number: user.license_number || null,
                staff_type: user.staff_type || null,
                specialties: user.specialties || [],
                availability: user.availability || {},
                profile_data: user.profile_data || {},
            },
            token,
        });
    } catch (err: any) {
        context.error("Error during login:", err);
        return errorResponse(500, "Authentication failed due to a server error.");
    }
}

app.http("authSignup", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "auth/signup",
    handler: signup,
});

app.http("authLogin", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "auth/login",
    handler: login,
});
