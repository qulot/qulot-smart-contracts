import cronTime from "cron-time-generator";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { inspect } from "util";

enum JobType {
  TriggerOpenLottery,
  TriggerCloseLottery,
  TriggerDrawLottery,
}

type JobTypeKeys = keyof typeof JobType;

function getJobId(lotteryId: string, jobType: JobType) {
  switch (jobType) {
    case JobType.TriggerOpenLottery:
      return lotteryId + ":open";
    case JobType.TriggerCloseLottery:
      return lotteryId + ":close";
    case JobType.TriggerDrawLottery:
      return lotteryId + ":draw";
  }
}

function getJobCronSpec(periodDays: number[], periodHourOfDays: number, jobType: JobType) {
  switch (jobType) {
    case JobType.TriggerCloseLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 0);
    case JobType.TriggerDrawLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 3);
    case JobType.TriggerOpenLottery:
      return cronTime.onSpecificDaysAt(periodDays, periodHourOfDays, 5);
  }
}

task("init:QulotAutomationTrigger", "First init data for Qulot lottery after deployed")
  .addParam("address", "Qulot automation trigger contract address")
  .addParam("qulotAddress", "Qulot lottery contract address")
  .setAction(async function (taskArguments: TaskArguments, { ethers, network }) {
    // Get operator signer
    const [_, operator] = await ethers.getSigners();

    // Get network data for running script.
    const gasPrice = await ethers.provider.getGasPrice();

    if (operator) {
      console.log(`Init Qulot automation trigger using operator address ${operator.address}`);
      const qulotAutomationTrigger = await ethers.getContractAt(
        "QulotAutomationTrigger",
        taskArguments.address,
        operator,
      );

      const qulotLottery = await ethers.getContractAt("QulotLottery", taskArguments.qulotAddress);
      const lotteryIds = await qulotLottery.getLotteryIds();
      console.log(`Qulot lottery returns lotteries ${inspect(lotteryIds)}`);

      const triggerJobTypeKeys = Object.keys(JobType).filter((v) => isNaN(Number(v)));

      for (const lotteryId of lotteryIds) {
        const lottery = await qulotLottery.getLottery(lotteryId);
        console.log(`Add trigger jobs for lottery ${inspect(lottery)}`);

        const periodDays = lottery.periodDays.map((period) => period.toNumber());
        const periodHourOfDays = lottery.periodHourOfDays.toNumber();

        for (const jobTypeKey of triggerJobTypeKeys) {
          const triggerJobType = JobType[jobTypeKey as JobTypeKeys];
          const triggerJobId = getJobId(lotteryId, triggerJobType);
          const triggerJobCron = getJobCronSpec(periodDays, periodHourOfDays, triggerJobType);

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
    } else {
      console.error("Not setup owner for init Qulot automation trigger");
    }
  });
