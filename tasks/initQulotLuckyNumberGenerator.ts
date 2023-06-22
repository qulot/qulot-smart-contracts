import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import { getEnv, getEnvByNetwork } from "../utils/env";

task("init:QulotLuckyNumberGenerator", "First init data for QulotLuckyNumberGenerator after deployed")
  .addParam("address", "Qulot random number generator contract address")
  .addParam("qulot", "Qulot lottery contract address")
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [owner] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    console.log(`Init Qulot random generator using owner: ${owner.address}`);
    const qulotLuckyNumberGenerator = await ethers.getContractAt(
      "QulotLuckyNumberGenerator",
      taskArguments.address,
      owner,
    );

    const setQulotLotteryAddressTx = await qulotLuckyNumberGenerator
      .connect(owner)
      .setQulotLottery(taskArguments.qulot, {
        gasLimit: 500000,
        gasPrice: gasPrice.mul(2),
      });
    console.log(
      `[${new Date().toISOString()}] network=${network.name} message='Set qulot lottery address #${
        taskArguments.qulot
      }' hash=${setQulotLotteryAddressTx?.hash} signer=${owner.address}`,
    );

    const jobId = getEnvByNetwork("JOB_ID", network.name);
    if (jobId) {
      const setJobIdTx = await qulotLuckyNumberGenerator
        .connect(owner)
        .setJobId(ethers.utils.hexZeroPad(ethers.utils.toUtf8Bytes(jobId), 32), {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        });
      console.log(
        `[${new Date().toISOString()}] network=${network.name} message='Set job id #${taskArguments.qulot}' hash=${
          setJobIdTx?.hash
        } signer=${owner.address}`,
      );
    } else {
      console.error(`Invalid environment variable for network deployment: ${network.name}`, {
        jobId,
      });
    }

    const luckyNumberApiUrl = getEnv("LUCKY_NUMBER_API_URL");
    const luckyNumberHttpMethod = getEnv("LUCKY_NUMBER_HTTP_METHOD");
    if (luckyNumberApiUrl && luckyNumberHttpMethod && jobId) {
      const setApiConfigTx = await qulotLuckyNumberGenerator
        .connect(owner)
        .setApiConfig(luckyNumberApiUrl, luckyNumberHttpMethod, {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        });
      console.log(
        `[${new Date().toISOString()}] network=${network.name} message='Set api config #${taskArguments.qulot}' hash=${
          setApiConfigTx?.hash
        } signer=${owner.address}`,
      );
    } else {
      console.error(`Invalid environment variable for network deployment: ${network.name}`, {
        luckyNumberApiUrl,
        luckyNumberHttpMethod,
        jobId,
      });
    }
  });
