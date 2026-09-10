import * as crypto from "crypto";

export interface TokenPayload {
    user_id: string;
    role: string;
    full_name: string;
    phone_e164: string;
    external_auth_id?: string;
    patient_id: string | null;
    staff_profile_id: string | null;
    iat?: number;
    exp?: number;
}

function base64UrlEncode(str: string): string {
    return Buffer.from(str)
        .toString("base64")
        .replace(/=/g, "")
        .replace(/\+/g, "-")
        .replace(/\//g, "_");
}

function base64UrlDecode(str: string): string {
    let base64 = str.replace(/-/g, "+").replace(/_/g, "/");
    while (base64.length % 4) {
        base64 += "=";
    }
    return Buffer.from(base64, "base64").toString("utf8");
}

export function generateToken(payload: TokenPayload, expiresInSeconds: number = 7 * 24 * 3600): string {
    const secret = process.env.AUTH_JWT_SECRET || "dev_ruralhealth_jwt_secret_key_change_in_production_2026";
    const header = { alg: "HS256", typ: "JWT" };
    const now = Math.floor(Date.now() / 1000);
    const fullPayload: TokenPayload = {
        ...payload,
        iat: now,
        exp: now + expiresInSeconds,
    };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
    const dataToSign = `${encodedHeader}.${encodedPayload}`;

    const signature = crypto
        .createHmac("sha256", secret)
        .update(dataToSign)
        .digest("base64")
        .replace(/=/g, "")
        .replace(/\+/g, "-")
        .replace(/\//g, "_");

    return `${dataToSign}.${signature}`;
}

export function verifyToken(token: string): { valid: boolean; payload?: TokenPayload; error?: string } {
    if (!token) {
        return { valid: false, error: "Token is empty" };
    }

    const parts = token.split(".");
    if (parts.length !== 3) {
        return { valid: false, error: "Malformed token format" };
    }

    const [encodedHeader, encodedPayload, signature] = parts;
    const secret = process.env.AUTH_JWT_SECRET || "dev_ruralhealth_jwt_secret_key_change_in_production_2026";
    const dataToSign = `${encodedHeader}.${encodedPayload}`;

    const expectedSignature = crypto
        .createHmac("sha256", secret)
        .update(dataToSign)
        .digest("base64")
        .replace(/=/g, "")
        .replace(/\+/g, "-")
        .replace(/\//g, "_");

    if (signature !== expectedSignature) {
        return { valid: false, error: "Invalid token signature" };
    }

    try {
        const payload: TokenPayload = JSON.parse(base64UrlDecode(encodedPayload));
        const now = Math.floor(Date.now() / 1000);
        if (payload.exp && payload.exp < now) {
            return { valid: false, error: "Token has expired" };
        }
        return { valid: true, payload };
    } catch (e: any) {
        return { valid: false, error: "Failed to parse token payload" };
    }
}
