import cronTime from "cron-time-generator";
import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { inspect } from "util";

import { isEveryDay } from "../utils/cron";

enum JobType {
  TriggerCloseLottery = 1, // step 1
  TriggerDrawLottery = 2, // step 2
  TriggerRewardLottery = 3, // step 3
  TriggerOpenLottery = 0, // step 4
}

type JobTypeKeys = keyof typeof JobType;

function getJobId(lotteryId: string, jobType: JobType) {
  switch (jobType) {
    case JobType.TriggerCloseLottery:
      return lotteryId + ":close";
    case JobType.TriggerDrawLottery:
      return lotteryId + ":draw";
    case JobType.TriggerRewardLottery:
      return lotteryId + ":reward";
    case JobType.TriggerOpenLottery:
      return lotteryId + ":open";
  }
}

function getJobCronSpec(periodDays: number[], periodHourOfDays: number, jobType: JobType) {
  if (isEveryDay(periodDays)) {
    switch (jobType) {
      case JobType.TriggerCloseLottery:
        return cronTime.everyDayAt(periodHourOfDays, 0);
      case JobType.TriggerDrawLottery:
        return cronTime.everyDayAt(periodHourOfDays, 5);
      case JobType.TriggerRewardLottery:
        return cronTime.everyDayAt(periodHourOfDays, 10);
      case JobType.TriggerOpenLottery:
        return cronTime.everyDayAt(periodHourOfDays, 15);
    }
  }
  switch (jobType) {
    case JobType.TriggerCloseLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 0);
    case JobType.TriggerDrawLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 5);
    case JobType.TriggerRewardLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 10);
    case JobType.TriggerOpenLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 15);
  }
}

task("init:QulotAutomationTrigger", "First init data for QulotAutomationTrigger after deployed")
  .addParam("address", "Qulot automation trigger contract address")
  .addParam("qulot", "Qulot lottery contract address")
  .addOptionalParam("new", "First time init QulotAutomationTrigger", true)
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [owner, operator] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    console.log(`Init Qulot automation trigger using owner: ${owner.address}, operator: ${operator.address}`);
    const qulotAutomationTrigger = await ethers.getContractAt(
      "QulotAutomationTrigger",
      taskArguments.address,
      operator,
    );

    if (taskArguments.new) {
      const setQulotLotteryAddressTx = await qulotAutomationTrigger
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
    }

    const qulotLottery = await ethers.getContractAt("QulotLottery", taskArguments.qulot);
    const lotteryIds = await qulotLottery.getLotteryIds();
    console.log(`Qulot lottery returns lotteries ${inspect(lotteryIds)}`);

    const triggerJobTypeKeys = Object.keys(JobType).filter((v) => isNaN(Number(v)));

    const existsJobIds = await qulotAutomationTrigger.getJobIds();

    for (const lotteryId of lotteryIds) {
      const lottery = await qulotLottery.getLottery(lotteryId);
      console.log(`Add trigger jobs for lottery ${inspect(lottery)}`);

      const periodDays = lottery.periodDays.map((period: BigNumber) => period.toNumber());
      const periodHourOfDays = lottery.periodHourOfDays.toNumber();

      for (const jobTypeKey of triggerJobTypeKeys) {
        const triggerJobType = JobType[jobTypeKey as JobTypeKeys];
        const triggerJobId = getJobId(lotteryId, triggerJobType);
        const triggerJobCron = getJobCronSpec(periodDays, periodHourOfDays, triggerJobType);

        if (existsJobIds.includes(triggerJobId)) {
          console.warn(`Add trigger job ${triggerJobId} is exists, skip!`);
          continue;
        }

        console.log(
          `Add trigger job ${triggerJobId}, params: ${inspect({
            triggerJobId,
            lotteryId,
            triggerJobCron,
            triggerJobType,
          })}`,
        );

        const addTriggerJobTx = await qulotAutomationTrigger.addTriggerJob(
          triggerJobId,
          lotteryId,
          triggerJobCron,
          triggerJobType,
          {
            gasLimit: 500000,
            gasPrice: gasPrice.mul(2),
          },
        );

        console.log(
          `[${new Date().toISOString()}] network=${network.name} message='Add lottery #${triggerJobId}' hash=${
            addTriggerJobTx?.hash
          } signer=${operator.address}`,
        );
      }
    }
  });
