import { loadConfig, toGatewayConfig } from "./config.js";
import { startRegistryGateway, stopRegistryGateway } from "./server.js";
import { safeLog } from "./redact.js";

async function main(): Promise<void> {
  const config = loadConfig();
  const { server, port } = await startRegistryGateway({
    port: config.port,
    gatewayConfig: toGatewayConfig(config),
    upstream: config.upstream,
  });

  safeLog(`Soviez registry gateway ready on port ${port}`);

  const shutdown = async (signal: string) => {
    safeLog(`Received ${signal}, shutting down`);
    await stopRegistryGateway(server);
    process.exit(0);
  };

  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
