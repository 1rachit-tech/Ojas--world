import { DefaultAzureCredential } from "@azure/identity";
import { ServiceBusClient } from "@azure/service-bus";
import { config } from "./config";

let credential: DefaultAzureCredential | null = null;
let client: ServiceBusClient | null = null;

function azureCredential(): DefaultAzureCredential {
  credential ??= new DefaultAzureCredential();
  return credential;
}

export function serviceBusClient(): ServiceBusClient {
  if (client) return client;

  if (
    config.serviceBusAuthMode === "connection_string" ||
    !config.serviceBusFqdn
  ) {
    if (!config.serviceBusConnection) {
      throw new Error(
        "Service Bus requires SEARCH_SERVICE_BUS_CONNECTION or SEARCH_SERVICE_BUS_FQDN.",
      );
    }

    client = new ServiceBusClient(config.serviceBusConnection);
    return client;
  }

  client = new ServiceBusClient(
    config.serviceBusFqdn,
    azureCredential(),
  );
  return client;
}
