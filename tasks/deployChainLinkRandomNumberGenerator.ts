import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { getEnvByNetwork } from "../utils/env";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy:ChainLinkRandomNumberGenerator", "Deploy the ChainLink random number generator").setAction(async function (
  _: TaskArguments,
  { ethers, network, run },
) {
  const vrfCoordinator = getEnvByNetwork("VRF_COORDINATOR", network.name);
  const vrfSubscriptionId = getEnvByNetwork("VRF_SUBSCRIPTION_ID", network.name);
  const vrfKeyHash = getEnvByNetwork("VRF_KEY_HASH", network.name);
  if (vrfCoordinator && vrfSubscriptionId && vrfKeyHash) {
    // Deploy ChainLink random number contract
    console.warn("Trying deploy ChainLinkRandomNumberGenerator contract...");
    const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
    const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy(vrfCoordinator);
    await chainLinkRandomNumberGenerator.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    await chainLinkRandomNumberGenerator.setKeyHash(vrfKeyHash);
    await chainLinkRandomNumberGenerator.setSubscriptionId(vrfSubscriptionId);
    console.log(`ChainLinkRandomNumberGenerator deployed to: ${chainLinkRandomNumberGenerator.address}`);

    // Verify ChainLink random number contract
    console.log(`Trying verify ChainLinkRandomNumberGenerator contract to: ${chainLinkRandomNumberGenerator.address}`);
    await run("verify:verify", {
      address: chainLinkRandomNumberGenerator.address,
      constructorArguments: [vrfCoordinator],
    });
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      vrfCoordinator,
      vrfSubscriptionId,
    });
  }
});
