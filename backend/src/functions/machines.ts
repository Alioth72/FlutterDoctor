import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query } from "../db";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";

// GET /api/machines
export async function getMachines(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    try {
        const facilityId = request.query.get("facility_id") || null;
        const status = request.query.get("status") || null;

        if (facilityId && !isValidUuid(facilityId)) {
            return errorResponse(400, "Invalid facility_id format. Must be a valid UUID.");
        }

        const sql = `
            SELECT 
                m.machine_record_id,
                m.facility_id,
                f.name AS facility_name,
                m.machine_type,
                m.serial_number,
                m.status,
                m.last_service_at,
                m.telemetry,
                m.created_at,
                m.updated_at
            FROM health.machine_records m
            JOIN health.facilities f ON m.facility_id = f.facility_id
            WHERE ($1::uuid IS NULL OR m.facility_id = $1)
              AND ($2::text IS NULL OR m.status = $2)
            ORDER BY m.machine_type ASC;
        `;

        const result = await query(sql, [facilityId, status]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getMachines:", err);
        return errorResponse(500, "Internal server error fetching machine records.");
    }
}

app.http("getMachines", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "machines",
    handler: getMachines,
});
