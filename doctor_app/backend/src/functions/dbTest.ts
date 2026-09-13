import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query } from "../db";

export async function dbTest(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log(`HTTP db-test function processed request for url "${request.url}"`);

    try {
        // Read-only server & schema check
        const infoResult = await query("SELECT current_database(), current_schema(), version();");
        
        // Read-only schema verification on health schema
        const healthCheckResult = await query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'health' ORDER BY table_name;"
        );

        const constraintsResult = await query(`
            SELECT c.conname, cl.relname, pg_get_constraintdef(c.oid) as def
            FROM pg_constraint c
            JOIN pg_namespace n ON n.oid = c.connamespace
            JOIN pg_class cl ON cl.oid = c.conrelid
            WHERE n.nspname = 'health' AND cl.relname IN ('medical_records', 'appointments', 'users', 'prescriptions');
        `);

        const medicalRecordCols = await query(`
            SELECT column_name, data_type, udt_name, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'health' AND table_name = 'medical_records';
        `);

        const distinctRecordTypes = await query("SELECT DISTINCT record_type FROM health.medical_records;");
        const distinctApptTypes = await query("SELECT DISTINCT appointment_type FROM health.appointments;");
        const distinctApptStatuses = await query("SELECT DISTINCT status FROM health.appointments;");
        const distinctRoles = await query("SELECT DISTINCT role FROM health.users;");

        return {
            status: 200,
            headers: {
                "Content-Type": "application/json",
            },
            jsonBody: {
                success: true,
                database: infoResult.rows[0].current_database,
                current_schema: infoResult.rows[0].current_schema,
                constraints: constraintsResult.rows,
                medical_record_cols: medicalRecordCols.rows,
                distinct_record_types: distinctRecordTypes.rows.map((r: any) => r.record_type),
                distinct_appt_types: distinctApptTypes.rows.map((r: any) => r.appointment_type),
                distinct_appt_statuses: distinctApptStatuses.rows.map((r: any) => r.status),
                distinct_roles: distinctRoles.rows.map((r: any) => r.role),
                connected: true,
                timestamp: new Date().toISOString(),
            },
        };
    } catch (error: any) {
        context.error("Database connection error:", error);
        return {
            status: 500,
            headers: {
                "Content-Type": "application/json",
            },
            jsonBody: {
                success: false,
                error: error.message,
                connected: false,
            },
        };
    }
}

app.http("db-test", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "db-test",
    handler: dbTest,
});
