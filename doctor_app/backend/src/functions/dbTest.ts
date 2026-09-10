import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { query } from "../db";

export async function dbTest(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log(`HTTP db-test function processed request for url "${request.url}"`);

    try {
        // Read-only server & schema check
        const infoResult = await query("SELECT current_database(), current_schema(), version();");
        
        // Read-only schema verification on health schema
        const healthCheckResult = await query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'health' ORDER BY table_name LIMIT 5;"
        );

        return {
            status: 200,
            headers: {
                "Content-Type": "application/json",
            },
            jsonBody: {
                success: true,
                database: infoResult.rows[0].current_database,
                current_schema: infoResult.rows[0].current_schema,
                version: infoResult.rows[0].version,
                health_schema_tables: healthCheckResult.rows.map((r: { table_name: string }) => r.table_name),
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
