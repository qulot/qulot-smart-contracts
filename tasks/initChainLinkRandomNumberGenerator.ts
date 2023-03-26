import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

task("init:ChainLinkRandomNumberGenerator", "First init data for ChainLinkRandomNumberGenerator after deployed")
  .addParam("address", "ChainLink random number generator contract address")
  .addParam("qulotAddress", "Qulot lottery contract address")
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [owner] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    console.log(`Init ChainLink random generator using owner: ${owner.address}`);
    const chainLinkRandomNumberGenerator = await ethers.getContractAt(
      "ChainLinkRandomNumberGenerator",
      taskArguments.address,
      owner,
    );

    const setQulotLotteryAddressTx = await chainLinkRandomNumberGenerator
      .connect(owner)
      .setQulotLottery(taskArguments.qulotAddress, {
        gasLimit: 500000,
        gasPrice: gasPrice.mul(2),
      });
    console.log(
      `[${new Date().toISOString()}] network=${network.name} message='Set qulot lottery address #${
        taskArguments.qulotAddress
      }' hash=${setQulotLotteryAddressTx?.hash} signer=${owner.address}`,
    );
  });
