import { getEnvByCurrentNetwork } from "@/utils/env";
import { ethers, network } from "hardhat";

async function main() {
  const vrfCoordinator = getEnvByCurrentNetwork("VRF_COORDINATOR");
  const vrfSubscriptionId = getEnvByCurrentNetwork("VRF_SUBSCRIPTION_ID");
  const tokenAddress = getEnvByCurrentNetwork("TOKEN_ADDRESS");
  const operatorAddress = getEnvByCurrentNetwork("OPERATOR_ADDRESS");
  const treasuryAddress = getEnvByCurrentNetwork("TREASURY_ADDRESS");
  if (vrfCoordinator && vrfSubscriptionId && tokenAddress && operatorAddress && treasuryAddress) {
    // Deploy ChainLink random number contract
    const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
    const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy(
      vrfCoordinator,
      vrfSubscriptionId,
    );
    await chainLinkRandomNumberGenerator.deployed();

    // Deploy Qulot lottery contract
    const QulotLottery = await ethers.getContractFactory("QulotLottery");
    const qulotLottery = await QulotLottery.deploy(tokenAddress, chainLinkRandomNumberGenerator.address);
    await qulotLottery.deployed();
    await qulotLottery.setOperatorAddress(operatorAddress);
    await qulotLottery.setTreasuryAddress(treasuryAddress);

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
