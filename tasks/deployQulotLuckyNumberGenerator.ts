import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { getEnvByNetwork } from "../utils/env";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy:QulotLuckyNumberGenerator", "Deploy the Qulot random number generator").setAction(async function (
  _: TaskArguments,
  { ethers, network, run },
) {
  const linkTokenAddress = getEnvByNetwork("LINK_TOKEN_ADDRESS", network.name);
  const oracleAddress = getEnvByNetwork("ORACLE_ADDRESS", network.name);
  if (linkTokenAddress && oracleAddress) {
    // Deploy ChainLink random number contract
    console.warn("Trying deploy QulotLuckyNumberGenerator contract...");
    const QulotLuckyNumberGenerator = await ethers.getContractFactory("QulotLuckyNumberGenerator");
    const qulotLuckyNumberGenerator = await QulotLuckyNumberGenerator.deploy(linkTokenAddress, oracleAddress);
    await qulotLuckyNumberGenerator.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
    console.log(`QulotLuckyNumberGenerator deployed to: ${qulotLuckyNumberGenerator.address}`);

    const apiKey = await qulotLuckyNumberGenerator.getApiKey();
    console.log(`QulotLuckyNumberGenerator api key result: ${apiKey}`);

    // Verify ChainLink random number contract
    console.log(`Trying verify QulotLuckyNumberGenerator contract to: ${qulotLuckyNumberGenerator.address}`);
    await run("verify:verify", {
      address: qulotLuckyNumberGenerator.address,
      constructorArguments: [linkTokenAddress, oracleAddress],
    });
  } else {
    console.error(`Invalid environment variable for network deployment: ${network.name}`, {
      linkTokenAddress,
      oracleAddress,
    });
  }
});
