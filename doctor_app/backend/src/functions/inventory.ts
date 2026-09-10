import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query } from "../db";
import { isValidUuid, jsonResponse, errorResponse } from "../utils";

// GET /api/inventory
export async function getInventory(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    try {
        const facilityId = request.query.get("facility_id") || null;
        const category = request.query.get("category") || null;

        if (facilityId && !isValidUuid(facilityId)) {
            return errorResponse(400, "Invalid facility_id format. Must be a valid UUID.");
        }

        const sql = `
            SELECT 
                i.inventory_id,
                i.facility_id,
                f.name AS facility_name,
                i.item_code,
                i.item_name,
                i.category,
                i.quantity,
                i.reorder_level,
                i.unit,
                i.expiry_date,
                i.batch_number,
                i.metadata,
                i.updated_at,
                (i.quantity <= i.reorder_level) AS is_low_stock
            FROM health.inventory i
            JOIN health.facilities f ON i.facility_id = f.facility_id
            WHERE ($1::uuid IS NULL OR i.facility_id = $1)
              AND ($2::text IS NULL OR i.category = $2)
            ORDER BY i.item_name ASC;
        `;

        const result = await query(sql, [facilityId, category]);
        return jsonResponse(200, {
            success: true,
            count: result.rows.length,
            data: result.rows,
        });
    } catch (err: any) {
        context.error("Error in getInventory:", err);
        return errorResponse(500, "Internal server error fetching inventory.");
    }
}

app.http("getInventory", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "inventory",
    handler: getInventory,
});
