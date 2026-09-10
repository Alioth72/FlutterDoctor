import { HttpRequest, HttpResponseInit } from "@azure/functions";
import { verifyToken, TokenPayload } from "./token";
import { errorResponse } from "../utils";

export function extractBearerToken(request: HttpRequest): string | null {
    const authHeader = request.headers.get("authorization") || request.headers.get("Authorization");
    if (!authHeader) {
        return null;
    }
    const parts = authHeader.trim().split(" ");
    if (parts.length === 2 && parts[0].toLowerCase() === "bearer") {
        return parts[1];
    }
    return null;
}

export function authenticate(request: HttpRequest): HttpResponseInit | TokenPayload {
    const token = extractBearerToken(request);
    if (!token) {
        return errorResponse(401, "Authentication required. Missing Bearer token in Authorization header.");
    }

    const verification = verifyToken(token);
    if (!verification.valid || !verification.payload) {
        return errorResponse(401, `Authentication failed: ${verification.error || "Invalid token"}`);
    }

    return verification.payload;
}
