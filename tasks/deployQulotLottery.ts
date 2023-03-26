import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { getEnvByNetwork } from "../utils/env";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy:QulotLottery", "Deploy the QulotLottery contract").setAction(async function (
  _: TaskArguments,
  { ethers, run, network },
) {
  const tokenAddress = getEnvByNetwork("TOKEN_ADDRESS", network.name);
  if (tokenAddress) {
    const [_, operator, treasury] = await ethers.getSigners();

    // Deploy Qulot lottery contract
    console.warn("Trying deploy QulotLottery contract...");
    const QulotLottery = await ethers.getContractFactory("QulotLottery");
    const qulotLottery = await QulotLottery.deploy(tokenAddress);
    await qulotLottery.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    await qulotLottery.setOperatorAddress(operator.address);
    await qulotLottery.setTreasuryAddress(treasury.address);
    console.log(`QulotLottery deployed to: ${qulotLottery.address}`);

    // Verify Qulot lottery contract
    console.log(`Trying verify QulotLottery contract to: ${qulotLottery.address}`);
    await run("verify:verify", {
      address: qulotLottery.address,
      constructorArguments: [tokenAddress],
    });
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      tokenAddress,
    });
  }
});
