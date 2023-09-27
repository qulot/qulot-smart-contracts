import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("contracts/QulotAutomationTrigger", function () {
  async function deployQulotAutomationTriggerFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, operatorAccount, otherAccount] = await ethers.getSigners();
    const qulotAutomationTrigger = await (await ethers.getContractFactory("QulotAutomationTrigger")).deploy();
    await qulotAutomationTrigger.setOperatorAddress(operatorAccount.address);
    return { qulotAutomationTrigger, owner, operatorAccount, otherAccount };
  }

  describe("addTriggerJob", function () {
    describe("Validations", function () {
      it("Should fail if invalid job id", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Test invalid job id
        await expect(
          qulotAutomationTrigger.connect(operatorAccount).addTriggerJob("", "liteq", "*/1 * * * *", "0"),
        ).to.revertedWith("ERROR_INVALID_JOB_ID");
      });

      it("Should fail if invalid lottery id", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Test invalid lottery id
        await expect(
          qulotAutomationTrigger.connect(operatorAccount).addTriggerJob("liteq:open", "", "*/1 * * * *", "0"),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_ID");
      });

      it("Should fail if cron spec empty string", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Test invalid lottery cron spec
        await expect(
          qulotAutomationTrigger.connect(operatorAccount).addTriggerJob("liteq:open", "liteq", "", "0"),
        ).to.revertedWith("ERROR_INVALID_JOB_CRON_SPEC");
      });

      it("Should fail if invalid cron spec", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Test invalid lottery cron spec
        await expect(
          qulotAutomationTrigger.connect(operatorAccount).addTriggerJob("liteq:open", "liteq", "2342345", "0"),
        ).to.revertedWithCustomError(qulotAutomationTrigger, "InvalidSpec");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotAutomationTrigger, operatorAccount, otherAccount } = await loadFixture(
          deployQulotAutomationTriggerFixture,
        );

        await qulotAutomationTrigger.setOperatorAddress(otherAccount.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotAutomationTrigger.connect(operatorAccount).addTriggerJob("liteq:open", "liteq", "*/1 * * * *", "0"),
        ).to.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Will match all if adding new trigger job is successful", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Register new lottery first
        await qulotAutomationTrigger
          .connect(operatorAccount)
          .addTriggerJob("liteq:open", "liteq", "5 17 * * 0,1,2,3,4,5,6", "0");

        expect(await qulotAutomationTrigger.getJobIds()).to.includes("liteq:open");
        const triggerLiteQOpen = await qulotAutomationTrigger.getJob("liteq:open");
        expect(triggerLiteQOpen.lotteryId).to.equal("liteq");
        expect(triggerLiteQOpen.jobType).to.equal(0);
      });
    });
  });

  describe("removeTriggerJob", function () {
    describe("Data", function () {
      it("Remove trigger job is successful", async function () {
        const { qulotAutomationTrigger, operatorAccount } = await loadFixture(deployQulotAutomationTriggerFixture);

        // Register new lottery first
        await qulotAutomationTrigger
          .connect(operatorAccount)
          .addTriggerJob("liteq:open", "liteq", "5 17 * * 0,1,2,3,4,5,6", "0");

        // Register new lottery first
        await qulotAutomationTrigger.connect(operatorAccount).removeTriggerJob("liteq:open");

        expect(await qulotAutomationTrigger.getJobIds()).to.not.includes("liteq:open");
        const triggerLiteQOpen = await qulotAutomationTrigger.getJob("liteq:open");
        expect(triggerLiteQOpen.isExists).to.equal(false);
      });
    });
  });
});
