import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import { getEnvByNetwork } from "../utils/env";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy", "Deploy the Qulot lottery contract to the network").setAction(async function (
  taskArguments: TaskArguments,
  { ethers, network, run },
) {
  const vrfCoordinator = getEnvByNetwork("VRF_COORDINATOR", network.name);
  const vrfSubscriptionId = getEnvByNetwork("VRF_SUBSCRIPTION_ID", network.name);
  const tokenAddress = getEnvByNetwork("TOKEN_ADDRESS", network.name);
  if (vrfCoordinator && vrfSubscriptionId && tokenAddress) {
    const [_, operator, treasury] = await ethers.getSigners();

    // Deploy Qulot automation trigger contract
    console.warn("Trying deploy QulotAutomationTrigger contract...");
    const QulotAutomationTrigger = await ethers.getContractFactory("QulotAutomationTrigger");
    const qulotAutomationTrigger = await QulotAutomationTrigger.deploy();
    await qulotAutomationTrigger.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    console.log(`QulotAutomationTrigger deployed to: ${qulotAutomationTrigger.address}`);
    // await run("verify:verify", {
    //   address: qulotAutomationTrigger.address,
    //   constructorArguments: [],
    // });

    // Deploy ChainLink random number contract
    console.warn("Trying deploy ChainLinkRandomNumberGenerator contract...");
    const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
    const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy(
      vrfCoordinator,
      vrfSubscriptionId,
    );
    await chainLinkRandomNumberGenerator.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    console.log(`ChainLinkRandomNumberGenerator deployed to: ${chainLinkRandomNumberGenerator.address}`);
    // await run("verify:verify", {
    //   address: chainLinkRandomNumberGenerator.address,
    //   constructorArguments: [vrfCoordinator, vrfSubscriptionId],
    // });

    // Deploy Qulot lottery contract
    console.warn("Trying deploy QulotLottery contract...");
    const QulotLottery = await ethers.getContractFactory("QulotLottery");
    const qulotLottery = await QulotLottery.deploy(tokenAddress, chainLinkRandomNumberGenerator.address);
    await qulotLottery.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    await qulotLottery.setOperatorAddress(operator.address);
    await qulotLottery.setTreasuryAddress(treasury.address);
    await qulotLottery.setTriggerAddress(qulotAutomationTrigger.address);
    console.log(`QulotLottery deployed to: ${qulotLottery.address}`);
    // await run("verify:verify", {
    //   address: qulotLottery.address,
    //   constructorArguments: [tokenAddress, chainLinkRandomNumberGenerator.address],
    // });

    // Set lottery address for ChainLink random number contract
    await qulotAutomationTrigger.setOperatorAddress(operator.address);
    await chainLinkRandomNumberGenerator.setQulotLottery(qulotLottery.address);
    await qulotAutomationTrigger.setQulotLottery(qulotLottery.address);
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      vrfCoordinator,
      vrfSubscriptionId,
      tokenAddress,
    });
  }
});
