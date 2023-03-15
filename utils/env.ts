import { snakeCase } from "snake-case";

/**
 * @example
 * getEnvByNetwork("ApiKey", "polygon-mumbai")
 * getEnvByNetwork("API_KEY", "polygon-mumbai")
 * getEnvByNetwork("Api_Key", "polygon-mumbai")
 * // returns process.env[NETWORK_POLYGON_MUMBAI_API_KEY]
 * @param key environment key
 * @param network environment network key
 * @param defaultValue default value if not found
 * @returns
 */
export function getEnvByNetwork(key: string, network: string, defaultValue?: string) {
  const combineKey = ["network", network.toLowerCase(), key].join("_");
  const envKey = snakeCase(combineKey).toUpperCase();
  return process.env[envKey] || defaultValue;
}
