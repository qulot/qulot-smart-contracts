import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import moment from "moment";

import { QulotLottery } from "../types";

describe("contracts/QulotLottery", function () {
  async function deployQulotLotteryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, operatorAccount] = await ethers.getSigners();
    const usdc = await (await ethers.getContractFactory("MockERC20")).deploy("USD Coin", "USDC", parseEther("10000"));
    const randomNumberGenerator = await (await ethers.getContractFactory("MockRandomNumberGenerator")).deploy();
    const qulotLottery = await (
      await ethers.getContractFactory("QulotLottery")
    ).deploy(usdc.address, randomNumberGenerator.address);
    await qulotLottery.setOperatorAddress(operatorAccount.address);
    await randomNumberGenerator.setQulotLottery(qulotLottery.address);
    return { qulotLottery, randomNumberGenerator, owner, otherAccount, operatorAccount };
  }

  async function initLottery(qulotLottery: QulotLottery, account: SignerWithAddress) {
    qulotLottery = await qulotLottery.connect(account);

    await (
      await qulotLottery.addLottery(
        "liteq",
        "https://cdn.qulot.io/img/product-megaq.png",
        "LiteQ",
        "3",
        "1",
        "66",
        ["1", "2", "3", "4", "5", "6"],
        "24",
        "10000",
        parseEther("1"),
        "10",
        "10",
      )
    ).wait();

    return qulotLottery;
  }

  describe("addLottery", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery id
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_ID");
      });

      it("Should fail if invalid picture", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

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
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PICTURE");
      });

      it("Should fail if invalid verbose name", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery verbose name
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_VERBOSE_NAME");
      });

      it("Should fail if invalid number rules", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery number of items
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "0",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS");

        // Test invalid lottery min value per item
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "0",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS");

        // Test invalid lottery max value per item
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "0",
              ["1", "2", "3", "4", "5", "6"],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS");
      });

      it("Should fail if invalid period draw time", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery period days
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              [],
              "18",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_DAYS");

        // Test invalid lottery period hour of days
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "25",
              "10000",
              parseEther("1.0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS");
      });

      it("Should fail if invalid price", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);
        // Test invalid lottery price per ticket
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("0"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PRICE_PER_TICKET");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } = await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorAddress(otherAccount.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Should fail if lottery already exist", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery first
        await qulotLottery
          .connect(operatorAccount)
          .addLottery(
            "liteq",
            "https://cdn.qulot.io/img/product-megaq.png",
            "LiteQ",
            "3",
            "1",
            "66",
            ["1", "2", "3", "4", "5", "6"],
            "24",
            "10000",
            parseEther("1"),
            "10",
            "10",
          );

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10",
              "10",
            ),
        ).to.revertedWith("ERROR_LOTTERY_ALREADY_EXISTS");
      });

      it("Will match all if adding new lottery is successful", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery first
        await qulotLottery
          .connect(operatorAccount)
          .addLottery(
            "liteq",
            "https://cdn.qulot.io/img/product-megaq.png",
            "LiteQ",
            "3",
            "1",
            "66",
            ["1", "2", "3", "4", "5", "6"],
            "24",
            "10000",
            parseEther("1"),
            "10",
            "10",
          );

        // Register new lottery again, Expect error lottery already exists
        const liteq = await qulotLottery.getLottery("liteq");
        expect(liteq).to.an("array").that.includes("LiteQ");
        expect(liteq).to.an("array").that.includes("https://cdn.qulot.io/img/product-megaq.png");
        expect(await qulotLottery.getLotteryIds()).to.includes("liteq");
      });
    });

    describe("Events", function () {
      it("Should emit an event on new lottery", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery
            .connect(operatorAccount)
            .addLottery(
              "liteq",
              "https://cdn.qulot.io/img/product-megaq.png",
              "LiteQ",
              "3",
              "1",
              "66",
              ["1", "2", "3", "4", "5", "6"],
              "24",
              "10000",
              parseEther("1"),
              "10",
              "10",
            ),
        )
          .to.emit(qulotLottery, "NewLottery")
          .withArgs("liteq", "LiteQ");
      });
    });
  });

  describe("addRewardRules", function () {
    describe("Validations", function () {
      it("Should fail if invalid rules array", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery id
        await expect(
          qulotLottery.connect(operatorAccount).addRewardRules("", ["2"], ["0", "0"], ["40", "50"]),
        ).to.revertedWith("ERROR_INVALID_RULES");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } = await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorAddress(otherAccount.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery.connect(operatorAccount).addRewardRules("liteq", ["1", "2"], ["0", "0"], ["40", "50"]),
        ).to.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Will match all if adding new rules is successful", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.connect(operatorAccount).addRewardRules("liteq", ["1", "2"], ["0", "0"], ["40", "50"]);
        const ruleMatch1 = await qulotLottery.rulesPerLotteryId("liteq", 0);
        expect(ruleMatch1.matchNumber).to.equal(1);
        expect(ruleMatch1.rewardUnit).to.equal(0);
        expect(ruleMatch1.rewardValue).to.equal("40");
        const ruleMatch2 = await qulotLottery.rulesPerLotteryId("liteq", 1);
        expect(ruleMatch2.matchNumber).to.equal(2);
        expect(ruleMatch2.rewardUnit).to.equal(0);
        expect(ruleMatch2.rewardValue).to.equal("50");
      });
    });

    describe("Events", function () {
      it("Should emit an event on new rules", async function () {
        const { qulotLottery, operatorAccount } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery.connect(operatorAccount).addRewardRules("liteq", ["1", "2"], ["0", "0"], ["40", "50"]),
        ).to.emit(qulotLottery, "NewRewardRule");
      });
    });
  });

  describe("open", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operatorAccount = fixture.operatorAccount;
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, operatorAccount);
        await expect(qulotLottery.connect(operatorAccount).open("", moment.utc().unix())).to.revertedWith(
          "ERROR_INVALID_LOTTERY_ID",
        );
      });

      it("Should fail if invalid drawTime", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operatorAccount = fixture.operatorAccount;
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, operatorAccount);
        await expect(qulotLottery.open("liteq", "0")).to.revertedWith("ERROR_INVALID_ROUND_DRAW_TIME");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.setOperatorAddress(otherAccount.address);
        await expect(qulotLottery.connect(operatorAccount).open("liteq", "1")).to.revertedWith(
          "ERROR_ONLY_TRIGGER_OR_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("Operator cannot start a second round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operatorAccount = fixture.operatorAccount;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operatorAccount);
        await qulotLottery.open("liteq", "1");
        await expect(qulotLottery.open("liteq", "1")).to.revertedWith("ERROR_NOT_TIME_OPEN_LOTTERY");
      });

      it("Will match all if open lottery successful", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operatorAccount = fixture.operatorAccount;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operatorAccount);
        await qulotLottery.open("liteq", "1");
        expect(await qulotLottery.getRound(1)).to.haveOwnProperty("status", 0);
        expect(await qulotLottery.currentRoundIdPerLottery("liteq")).to.equal(1);
      });
    });

    describe("Events", function () {
      it("Should emit an event on new round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operatorAccount = fixture.operatorAccount;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operatorAccount);
        // Check event emitted
        const result = await (await qulotLottery.open("liteq", "1")).wait();
        expect(result.events?.[0].args?.roundId).to.equal(1);
      });
    });
  });

  describe("close", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await expect(qulotLottery.connect(fixture.operatorAccount).close("")).to.revertedWith(
          "ERROR_INVALID_LOTTERY_ID",
        );
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operatorAccount, otherAccount } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.setOperatorAddress(otherAccount.address);
        await expect(qulotLottery.connect(operatorAccount).close("liteq")).to.revertedWith(
          "ERROR_ONLY_TRIGGER_OR_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("The operator can't close the lottery if he has not opened any round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        expect(await qulotLottery.close("liteq")).to.revertedWith("ERROR_NOT_TIME_CLOSE_LOTTERY");
      });
    });

    describe("Events", function () {
      it("Should emit an event on close round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.open("liteq", "1");
        await expect(qulotLottery.close("liteq")).to.emit(qulotLottery, "RoundClose");
      });
    });
  });

  describe("draw", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.close("liteq");
        await expect(qulotLottery.connect(fixture.operatorAccount).draw("")).to.revertedWith(
          "ERROR_INVALID_LOTTERY_ID",
        );
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.close("liteq");
        await expect(qulotLottery.connect(fixture.otherAccount).draw("liteq")).to.revertedWith(
          "ERROR_ONLY_TRIGGER_OR_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("The operator can't draw the lottery if he has not closed any round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.open("liteq", "1");
        await expect(qulotLottery.draw("liteq")).to.revertedWith("ERROR_NOT_TIME_DRAW_LOTTERY");
      });

      it("Should fail if invalid winning numbers", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.open("liteq", "1");
        await qulotLottery.close("liteq");

        // Check empty winning numbers
        await fixture.randomNumberGenerator.setRandomResult("1", []);
        await expect(qulotLottery.draw("liteq")).to.revertedWith(
          "ERROR_INVALID_WINNING_NUMBERS",
        );

        // Check min number
        await fixture.randomNumberGenerator.setRandomResult("1", ["0", "2", "3"]);
        await expect(qulotLottery.draw("liteq")).to.revertedWith(
          "ERROR_INVALID_WINNING_NUMBERS",
        );

        // Check min number
        await fixture.randomNumberGenerator.setRandomResult("1", ["1", "2", "99"]);
        await expect(qulotLottery.draw("liteq")).to.revertedWith(
          "ERROR_INVALID_WINNING_NUMBERS",
        );
      });
    });

    describe("Events", function () {
      it("Should emit an event on draw round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operatorAccount);
        await qulotLottery.open("liteq", "1");
        await qulotLottery.close("liteq");
        await expect(qulotLottery.draw("liteq")).to.emit(qulotLottery, "RoundDraw");
      });
    });
  });
});
