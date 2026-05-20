import "./loadEnv.js";
import {setGlobalOptions} from "firebase-functions";

setGlobalOptions({maxInstances: 10});

export * from "./auth/index.js";
export * from "./startups/index.js";
export * from "./wallet/index.js";
export * from "./balcao/index.js";
