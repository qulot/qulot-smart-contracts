import { network } from "hardhat";
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

/**
 * @example <caption>current network is polygon-mumbai</caption>
 * getEnvByCurrentNetwork("ApiKey")
 * getEnvByCurrentNetwork("API_KEY")
 * getEnvByCurrentNetwork("Api_Key")
 * // returns process.env[NETWORK_POLYGON_MUMBAI_API_KEY]
 * @param key string
 * @param defaultValue string
 * @returns
 */
export function getEnvByCurrentNetwork(key: string, defaultValue?: string) {
  return getEnvByNetwork(key, network.name, defaultValue);
}
