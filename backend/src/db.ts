import { Pool } from "pg";

const isSsl = process.env.PGSSL === "true" || process.env.PGSSL === "require";

export const pool = new Pool({
    host: process.env.PGHOST,
    port: parseInt(process.env.PGPORT || "5432", 10),
    database: process.env.PGDATABASE || "ruralhealth",
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    ssl: isSsl ? { rejectUnauthorized: false } : false,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
});

export async function query(text: string, params?: any[]) {
    return pool.query(text, params);
}
