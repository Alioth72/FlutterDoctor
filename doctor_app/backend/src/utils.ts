import { HttpResponseInit } from "@azure/functions";

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isValidUuid(val?: string | null): boolean {
    return !!val && UUID_REGEX.test(val);
}

export function jsonResponse(status: number, data: any): HttpResponseInit {
    return {
        status,
        headers: {
            "Content-Type": "application/json",
        },
        jsonBody: data,
    };
}

export function errorResponse(status: number, message: string): HttpResponseInit {
    return jsonResponse(status, {
        success: false,
        error: message,
    });
}
