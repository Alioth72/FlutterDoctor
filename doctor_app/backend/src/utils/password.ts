import * as bcrypt from "bcryptjs";

// Pre-computed dummy bcrypt hash (cost 12) used to thwart timing attacks on non-existent users
const DUMMY_HASH = "$2b$12$e8xLGB6Wl.9sN9/h0/8Vveo6aA2PzT0pP74xZ6j335O9Yw.cT4M2y";

/**
 * Validates password policy.
 * Requirements:
 * - Minimum 8 characters
 * - Non-empty string
 */
export function validatePasswordPolicy(password: string): { valid: boolean; message?: string } {
    if (!password || typeof password !== "string") {
        return { valid: false, message: "Password is required and must be a string." };
    }

    if (password.length < 8) {
        return { valid: false, message: "Password must be at least 8 characters in length." };
    }

    return { valid: true };
}

/**
 * Hashes a plaintext password using bcrypt with cost factor 12.
 */
export async function hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 12);
}

/**
 * Verifies a plaintext password against a stored bcrypt hash.
 */
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
    if (!password || !hash) return false;
    return bcrypt.compare(password, hash);
}

/**
 * Executes a dummy comparison to ensure constant-time response when user is not found.
 */
export async function dummyVerify(password: string): Promise<void> {
    try {
        await bcrypt.compare(password || "", DUMMY_HASH);
    } catch {
        // Ignore dummy comparison error
    }
}
