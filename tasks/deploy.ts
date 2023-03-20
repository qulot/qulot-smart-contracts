import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import { getEnvByNetwork } from "../utils/env";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy", "Deploy the Qulot lottery contract to the network").setAction(async function (
  taskArguments: TaskArguments,
  { ethers, network },
) {
  const vrfCoordinator = getEnvByNetwork("VRF_COORDINATOR", network.name);
  const vrfSubscriptionId = getEnvByNetwork("VRF_SUBSCRIPTION_ID", network.name);
  const vrfKeyHash = getEnvByNetwork("VRF_KEY_HASH", network.name);
  const tokenAddress = getEnvByNetwork("TOKEN_ADDRESS", network.name);
  if (vrfCoordinator && vrfSubscriptionId && vrfKeyHash && tokenAddress) {
    const [owner, operator, treasury] = await ethers.getSigners();

    // Deploy Qulot automation trigger contract
    console.warn("Trying deploy QulotAutomationTrigger contract...");
    const QulotAutomationTrigger = await ethers.getContractFactory("QulotAutomationTrigger");
    const qulotAutomationTrigger = await QulotAutomationTrigger.deploy();
    await qulotAutomationTrigger.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    console.log(`QulotAutomationTrigger deployed to: ${qulotAutomationTrigger.address}`);

    // Deploy ChainLink random number contract
    console.warn("Trying deploy ChainLinkRandomNumberGenerator contract...");
    const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
    const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy(vrfCoordinator);
    await chainLinkRandomNumberGenerator.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    await chainLinkRandomNumberGenerator.setKeyHash(vrfKeyHash);
    await chainLinkRandomNumberGenerator.setSubscriptionId(vrfSubscriptionId);
    console.log(`ChainLinkRandomNumberGenerator deployed to: ${chainLinkRandomNumberGenerator.address}`);

    // Deploy Qulot lottery contract
    console.warn("Trying deploy QulotLottery contract...");
    const QulotLottery = await ethers.getContractFactory("QulotLottery");
    const qulotLottery = await QulotLottery.deploy(tokenAddress, chainLinkRandomNumberGenerator.address);
    await qulotLottery.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    await qulotLottery.setOperatorAddress(operator.address);
    await qulotLottery.setTreasuryAddress(treasury.address);
    await qulotLottery.setTriggerAddress(qulotAutomationTrigger.address);
    console.log(`QulotLottery deployed to: ${qulotLottery.address}`);

    // // Set lottery address for ChainLink random number contract
    await chainLinkRandomNumberGenerator.setQulotLottery(qulotLottery.address);
    await qulotAutomationTrigger.setOperatorAddress(operator.address);
    await qulotAutomationTrigger.setQulotLottery(qulotLottery.address);
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      vrfCoordinator,
      vrfSubscriptionId,
      tokenAddress,
    });
  }
});
