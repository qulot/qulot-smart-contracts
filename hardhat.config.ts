import "@nomicfoundation/hardhat-toolbox";
import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import type { HardhatUserConfig } from "hardhat/config";
import type { HardhatNetworkAccountsUserConfig, HttpNetworkAccountsUserConfig, NetworkUserConfig } from "hardhat/types";
import { resolve } from "path";
import "solidity-coverage";

import "./tasks/deployChainLinkRandomNumberGenerator";
import "./tasks/deployQulotAutomationTrigger";
import "./tasks/deployQulotLottery";
import "./tasks/deployQulotLuckyNumberGenerator";
import "./tasks/initChainLinkRandomNumberGenerator";
import "./tasks/initQulotAutomationTrigger";
import "./tasks/initQulotLottery";
import "./tasks/initQulotLuckyNumberGenerator";
import { getEnvByNetwork } from "./utils/env";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
const mnemonic: string | undefined = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const etherScanApiKey = process.env.ETHERSCAN_API_KEY || "";
const polygonScanApiKey = process.env.POLYGONSCAN_API_KEY || "";
const bnbChainScanApiKey = process.env.BNBCHAIN_API_KEY || "";
const reportGas = process.env.REPORT_GAS ? true : false;

const chainIds = {
  sepolia: 11155111,
  bsc: 56,
  hardhat: 31337,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
};

type ChainKeys = keyof typeof chainIds;

function getChainAccountsConfig(
  chain: ChainKeys,
): HardhatNetworkAccountsUserConfig | HttpNetworkAccountsUserConfig | null {
  const ownerPrivateKey = getEnvByNetwork("OWNER_PRIVATE_KEY", chain);
  const operatorPrivateKey = getEnvByNetwork("OPERATOR_PRIVATE_KEY", chain);
  const treasuryPrivateKey = getEnvByNetwork("TREASURY_PRIVATE_KEY", chain);

  if (ownerPrivateKey && operatorPrivateKey && treasuryPrivateKey) {
    return [`0x${ownerPrivateKey}`, `0x${operatorPrivateKey}`, `0x${treasuryPrivateKey}`];
  }

  const ownerMnemonic = getEnvByNetwork("OWNER_MNEMONIC", chain);
  const operatorMnemonic = getEnvByNetwork("OPERATOR_MNEMONIC", chain);
  const treasuryMnemonic = getEnvByNetwork("TREASURY_MNEMONIC", chain);
  if (ownerMnemonic && operatorMnemonic && treasuryMnemonic) {
    const owner = ethers.Wallet.fromMnemonic(ownerMnemonic);
    const operator = ethers.Wallet.fromMnemonic(operatorMnemonic);
    const treasury = ethers.Wallet.fromMnemonic(treasuryMnemonic);
    return [owner.privateKey, operator.privateKey, treasury.privateKey];
  }

  return null;
}

function getChainConfig(chain: ChainKeys): NetworkUserConfig {
  let jsonRpcUrl: string;
  switch (chain) {
    case "bsc":
      jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }
  const networkUserConfig: NetworkUserConfig = {
    accounts: {
      count: 10,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };

  const networkUserAccounts = getChainAccountsConfig(chain);
  if (networkUserAccounts) {
    networkUserConfig.accounts = networkUserAccounts;
  }

  return networkUserConfig;
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  // https://www.npmjs.com/package/hardhat-gas-reporter
  gasReporter: {
    enabled: reportGas,
  },
  // https://www.npmjs.com/package/@nomiclabs/hardhat-etherscan
  etherscan: {
    apiKey: {
      sepolia: etherScanApiKey,
      polygon: polygonScanApiKey,
      polygonMumbai: polygonScanApiKey,
      bsc: bnbChainScanApiKey,
    },
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      },
      chainId: chainIds.hardhat,
      gas: 12000000,
      blockGasLimit: 999999999,
    },
    "polygon-mainnet": getChainConfig("polygon-mainnet"),
    "polygon-mumbai": getChainConfig("polygon-mumbai"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.6",
    settings: {
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
      },
    },
  },
  abiExporter: {
    path: "./data/abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [":QulotLottery$"],
    spacing: 2,
    format: "json",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [":QulotLottery$"],
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
};

export default config;
