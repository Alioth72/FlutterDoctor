import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

export async function hello(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log(`HTTP function processed request for url "${request.url}"`);

    const name = request.query.get('name') || 'world';

    return {
        status: 200,
        headers: {
            "Content-Type": "application/json"
        },
        jsonBody: {
            message: `Hello, ${name}! Azure Functions v4 backend scaffold is operational.`,
            timestamp: new Date().toISOString(),
            status: "online"
        }
    };
}

app.http('hello', {
    methods: ['GET'],
    authLevel: 'anonymous',
    handler: hello
});
