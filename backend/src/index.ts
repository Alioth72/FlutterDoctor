import { app } from "@azure/functions";

// Import all function modules to register routes with Azure Functions runtime
import "./functions/hello";
import "./functions/dbTest";
import "./functions/auth";
import "./functions/patients";
import "./functions/appointments";
import "./functions/inventory";
import "./functions/machines";
import "./functions/admin";

app.setup({
    enableHttpStream: true,
});
