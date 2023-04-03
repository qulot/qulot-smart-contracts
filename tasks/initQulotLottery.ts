import { BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { inspect } from "util";

import lotteriesInitData from "../data/lotteries.json";
import { Lottery } from "../typings/lottery";

task("init:QulotLottery", "First init data for Qulot lottery after deployed")
  .addParam("address", "Qulot lottery contract address")
  .addParam("random", "Qulot random number generator contract address")
  .addParam("automation", "Qulot automation trigger contract address")
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [owner, operator] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    console.log(`Init Qulot lottery using owner: ${owner.address}, operator: ${operator.address}`);
    const qulotLottery = await ethers.getContractAt("QulotLottery", taskArguments.address, operator);

    const setRandomGeneratorTx = await qulotLottery.connect(owner).setRandomGenerator(taskArguments.random, {
      gasLimit: 500000,
      gasPrice: gasPrice.mul(2),
    });
    console.log(
      `[${new Date().toISOString()}] network=${network.name} message='Set random generator contract address #${
        taskArguments.random
      }' hash=${setRandomGeneratorTx?.hash} signer=${owner.address}`,
    );
    const setAutomationTriggerTx = await qulotLottery.connect(owner).setTriggerAddress(taskArguments.automation, {
      gasLimit: 500000,
      gasPrice: gasPrice.mul(2),
    });
    console.log(
      `[${new Date().toISOString()}] network=${network.name} message='Set automation trigger contract address #${
        taskArguments.automation
      }' hash=${setAutomationTriggerTx?.hash} signer=${owner.address}`,
    );

    const lotteries = lotteriesInitData as Lottery[];
    for (const lottery of lotteries) {
      console.log(`Add lottery id: ${lottery.id}`);
      const addLotteryTx = await qulotLottery.addLottery(
        lottery.id,
        lottery.picture,
        lottery.verboseName,
        lottery.numberOfItems,
        lottery.minValuePerItem,
        lottery.maxValuePerItem,
        lottery.periodDays,
        lottery.periodHourOfDays,
        lottery.maxNumberTicketsPerBuy,
        parseEther(lottery.pricePerTicket.toString()),
        lottery.treasuryFeePercent,
        lottery.amountInjectNextRoundPercent,
        {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        },
      );

      console.log(
        `[${new Date().toISOString()}] network=${network.name} message='Add lottery #${lottery.id}' hash=${
          addLotteryTx?.hash
        } signer=${operator.address}`,
      );

      const rewardRules = lottery.rewardRules.reduce(
        (curr, rewardRule) => {
          curr.matchNumbers.push(rewardRule.matchNumber);
          curr.rewardUnits.push(rewardRule.rewardUnit);
          curr.rewardValues.push(parseEther(rewardRule.rewardValue.toString()));
          return curr;
        },
        {
          matchNumbers: [],
          rewardUnits: [],
          rewardValues: [],
        } as {
          matchNumbers: number[];
          rewardUnits: number[];
          rewardValues: BigNumber[];
        },
      );

      const addRewardRulesTx = await qulotLottery.addRewardRules(
        lottery.id,
        rewardRules.matchNumbers,
        rewardRules.rewardUnits,
        rewardRules.rewardValues,
        {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        },
      );
      console.log(
        `[${new Date().toISOString()}] network=${network.name} message='Add rules #${inspect(addRewardRulesTx)}' hash=${
          addRewardRulesTx?.hash
        } signer=${operator.address}`,
      );
    }
  });
