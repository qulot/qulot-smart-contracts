import { ethers, network } from "hardhat";

import { getEnvByNetwork } from "../utils/env";

async function main() {
  const vrfCoordinator = getEnvByNetwork("VRF_COORDINATOR", network.name);
  const vrfSubscriptionId = getEnvByNetwork("VRF_SUBSCRIPTION_ID", network.name);
  const tokenAddress = getEnvByNetwork("TOKEN_ADDRESS", network.name);
  const operatorAddress = getEnvByNetwork("OPERATOR_ADDRESS", network.name);
  const treasuryAddress = getEnvByNetwork("TREASURY_ADDRESS", network.name);
  if (vrfCoordinator && vrfSubscriptionId && tokenAddress && operatorAddress && treasuryAddress) {
    // Deploy ChainLink random number contract
    const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
    const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy(
      vrfCoordinator,
      vrfSubscriptionId,
    );
    await chainLinkRandomNumberGenerator.deployed();
    console.log(`ChainLinkRandomNumberGenerator deployed to: ${chainLinkRandomNumberGenerator.address}`);

    // Deploy Qulot lottery contract
    const QulotLottery = await ethers.getContractFactory("QulotLottery");
    const qulotLottery = await QulotLottery.deploy(tokenAddress, chainLinkRandomNumberGenerator.address);
    await qulotLottery.deployed();
    await qulotLottery.setOperatorAddress(operatorAddress);
    await qulotLottery.setTreasuryAddress(treasuryAddress);
    console.log(`QulotLottery deployed to: ${qulotLottery.address}`);

    // Set lottery address for ChainLink random number contract
    await chainLinkRandomNumberGenerator.setLotteryAddress(qulotLottery.address);
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      vrfCoordinator,
      vrfSubscriptionId,
      tokenAddress,
      operatorAddress,
      treasuryAddress,
    });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
