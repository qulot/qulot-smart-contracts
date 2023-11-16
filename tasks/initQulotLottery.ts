import { parseUnits } from "ethers/lib/utils";
import { task, types } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { inspect } from "util";

import lotteriesInitData from "../data/lotteries.json";
import { Lottery } from "../typings/lottery";

task("init:QulotLottery", "First init data for Qulot lottery after deployed")
  .addParam("address", "Qulot lottery contract address")
  .addParam("random", "Qulot random number generator contract address")
  .addParam("automation", "Qulot automation trigger contract address")
  .addOptionalParam("new", "First time init QulotLottery", true, types.boolean)
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [owner, operator] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    console.log(`Init Qulot lottery using owner: ${owner.address}, operator: ${operator.address}`);
    const qulotLottery = await ethers.getContractAt("QulotLottery", taskArguments.address, operator);
    const token = await ethers.getContractAt("ERC20", await qulotLottery.token());
    const [tokenSymbol, tokenDecimals] = await Promise.all([token.symbol(), token.decimals()]);

    // Fetch token info
    console.log(`Qulot lottery using token: ${tokenSymbol}, decimals: ${tokenDecimals}`);

    if (taskArguments.new) {
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
    }

    const lotteries = lotteriesInitData as Lottery[];
    for (const lottery of lotteries) {
      console.log(`Add lottery id: ${lottery.id}`);
      const addLotteryTx = await qulotLottery.addLottery(
        lottery.id,
        {
          verboseName: lottery.verboseName,
          picture: lottery.picture,
          numberOfItems: lottery.numberOfItems,
          minValuePerItem: lottery.minValuePerItem,
          maxValuePerItem: lottery.maxValuePerItem,
          maxNumberTicketsPerBuy: lottery.maxNumberTicketsPerBuy,
          amountInjectNextRoundPercent: lottery.amountInjectNextRoundPercent,
          periodDays: lottery.periodDays,
          periodHourOfDays: lottery.periodHourOfDays,
          pricePerTicket: parseUnits(lottery.pricePerTicket.toString(), tokenDecimals),
          treasuryFeePercent: lottery.treasuryFeePercent,
          discountPercent: lottery.discountPercent,
        },
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
      if (taskArguments.new) {
        const addRewardRulesTx = await qulotLottery.addRewardRules(lottery.id, lottery.rewardRules, {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        });
        console.log(
          `[${new Date().toISOString()}] network=${network.name} message='Add rules #${inspect(
            addRewardRulesTx,
          )}' hash=${addRewardRulesTx?.hash} signer=${operator.address}`,
        );

        const openLotteryTx = await qulotLottery.open(lottery.id, {
          gasLimit: 500000,
          gasPrice: gasPrice.mul(2),
        });
        console.log(
          `[${new Date().toISOString()}] network=${network.name} message='First time open lottery #${inspect(
            openLotteryTx,
          )}' hash=${openLotteryTx?.hash} signer=${operator.address}`,
        );
      }
    }
  });
