/**
 * Carrega `functions/.env` apenas no emulador (desenvolvimento local).
 * Em producao as variaveis vêm do Cloud Run / deploy.
 */
import dotenv from "dotenv";
import * as fs from "node:fs";
import * as path from "node:path";

if (process.env.FUNCTIONS_EMULATOR === "true") {
  const envPath = path.resolve(__dirname, "..", ".env");
  if (fs.existsSync(envPath)) {
    dotenv.config({path: envPath});
  }
}
