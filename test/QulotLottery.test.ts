import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { parseEther, parseUnits } from "ethers/lib/utils";

describe("QulotLottery", function () {
  async function deployQulotLotteryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, operatorAccount] = await ethers.getSigners();

    const usdc = await (
      await ethers.getContractFactory("MockERC20")
    ).deploy("USD Coin", "USDC", parseEther("10000"));

    const randomNumberGenerator = await (
      await ethers.getContractFactory("MockRandomNumberGenerator")
    ).deploy();

    const qulotLottery = await (
      await ethers.getContractFactory("QulotLottery")
    ).deploy(usdc.address, randomNumberGenerator.address);

    await qulotLottery.setOperatorAddress(operatorAccount.address);

    await randomNumberGenerator.setLotteryAddress(qulotLottery.address);

    return { qulotLottery, owner, otherAccount, operatorAccount };
  }

  describe("addLottery", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery id
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_ID");
      });

      it("Should fail if invalid picture", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery picture
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_PICTURE");
      });

      it("Should fail if invalid verbose name", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery verbose name
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_VERBOSE_NAME");
      });

      it("Should fail if invalid number rules", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery number of items
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "0",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS");

        // Test invalid lottery min value per item
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "0",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS");

        // Test invalid lottery max value per item
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "0",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS");
      });

      it("Should fail if invalid period draw time", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery period days
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              [],
              "18",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_DAYS");

        // Test invalid lottery period hour of days
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "25",
              "10000",
              parseEther("1.0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS");
      });

      it("Should fail if invalid price", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );
        // Test invalid lottery price per ticket
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("0"),
              "10"
            )
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_PRICE_PER_TICKET");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } =
          await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorAddress(otherAccount.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10"
            )
        ).to.be.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Should fail if lottery already exist", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Register new lottery first
        qulotLottery
          .connect(operatorAccount)
          .addLottery(
            "liteq",
            "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
            "LiteQ",
            "3",
            "1",
            "66",
            ["1", "2", "3", "4", "5", "6"],
            "24",
            "10000",
            parseEther("1"),
            "10"
          );

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10"
            )
        ).to.be.revertedWith("ERROR_LOTTERY_ALREADY_EXISTS");
      });

      it("Will match all if adding new lottery is successful", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Register new lottery first
        await qulotLottery
          .connect(operatorAccount)
          .addLottery(
            "liteq",
            "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
            "LiteQ",
            "3",
            "1",
            "66",
            ["1", "2", "3", "4", "5", "6"],
            "24",
            "10000",
            parseEther("1"),
            "10"
          );

        // Register new lottery again, Expect error lottery already exists
        const liteq = await qulotLottery.lotteries("liteq");
        await expect(liteq).to.be.an("array").that.includes("LiteQ");
        expect(liteq)
          .to.be.an("array")
          .that.includes(
            "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png"
          );
      });
    });

    describe("Events", function () {
      it("Should emit an event on new lottery", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "ipfs://QmeMHMZVXQCWTjiMmQeQ3g1cQ5FHz5Yypf9wsBW8anR1RR/0.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10"
            )
        )
          .to.emit(qulotLottery, "NewLottery")
          .withArgs("liteq", "LiteQ");
      });
    });
  });

  describe("addRule", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid lottery id
        await expect(
          qulotLottery.connect(operatorAccount).addRule("", "1", "0", "50")
        ).to.be.revertedWith("ERROR_INVALID_LOTTERY_ID");
      });

      it("Should fail if invalid match number", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid match number
        await expect(
          qulotLottery.connect(operatorAccount).addRule("liteq", "0", "0", "50")
        ).to.be.revertedWith("ERROR_INVALID_RULE_MATCH_NUMBER");
      });

      it("Should fail if invalid reward value", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(
          deployQulotLotteryFixture
        );

        // Test invalid reward value of rule
        await expect(
          qulotLottery.connect(operatorAccount).addRule("liteq", "1", "0", "0")
        ).to.be.revertedWith("ERROR_INVALID_RULE_REWARD_VALUE");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } =
          await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorAddress(otherAccount.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery.connect(operatorAccount).addRule("liteq", "1", "0", "50")
        ).to.be.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Will match all if adding new rule is successful", async function () {
        const { qulotLottery, operatorAccount, otherAccount } =
          await loadFixture(deployQulotLotteryFixture);
        await qulotLottery
          .connect(operatorAccount)
          .addRule("liteq", "1", "0", "50");
        var newRule = await qulotLottery.rulesPerLotteryId("liteq", 0);

        expect(newRule).to.be.an("array").includes(1);
        expect(newRule).to.be.an("array").includes(0);
      });
    });
  });

  
});
