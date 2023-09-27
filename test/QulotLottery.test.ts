import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

import { QulotLottery } from "../types";
import { LotteryStruct, RuleStruct } from "../types/contracts/QulotLottery";

describe("contracts/QulotLottery", function () {
  const lotteryLiteQ: LotteryStruct = {
    verboseName: "LiteQ",
    picture: "https://cdn.qulot.io/img/product-megaq.png",
    numberOfItems: "3",
    minValuePerItem: "1",
    maxValuePerItem: "66",
    periodDays: ["1", "2", "3", "4", "5", "6"],
    periodHourOfDays: "24",
    maxNumberTicketsPerBuy: "4",
    pricePerTicket: parseEther("1"),
    treasuryFeePercent: "10",
    amountInjectNextRoundPercent: "10",
    discountPercent: "10",
  };

  const lotteryLiteQRules: RuleStruct[] = [
    {
      matchNumber: 3,
      rewardValue: 70,
    },
    {
      matchNumber: 2,
      rewardValue: 30,
    },
  ];

  async function deployQulotLotteryFixture() {
    const totalInitSupply = parseEther("10000");

    // Contracts are deployed using the first signer/account by default
    const [owner, treasury, operator, trigger, other, lisa, rose, bob, micky, rick] = await ethers.getSigners();

    // Mock erc20 token
    const token = await (await ethers.getContractFactory("MockERC20")).deploy("USD Coin", "USDC", totalInitSupply);
    console.log(`MockERC20 deployed: ${token.address}`);

    // Mock random number generator
    const randomNumberGenerator = await (await ethers.getContractFactory("MockRandomNumberGenerator")).deploy();
    console.log(`RandomNumberGenerator deployed: ${randomNumberGenerator.address}`);

    // Mock qulot lottery
    const qulotLottery = await (await ethers.getContractFactory("QulotLottery")).deploy(token.address);
    console.log(`QulotLottery deployed: ${qulotLottery.address}`);
    await qulotLottery.setRandomGenerator(randomNumberGenerator.address);
    await qulotLottery.setOperatorTreasuryAddress(operator.address, treasury.address);
    await qulotLottery.setTriggerAddress(trigger.address);
    await randomNumberGenerator.setQulotLottery(qulotLottery.address);

    // Mock account token balance
    for (const acc of [lisa, rose, bob, micky, rick]) {
      await token.connect(acc).mintTokens(parseEther("10000"));
      await token.connect(acc).approve(qulotLottery.address, parseEther("10000"));
    }

    return {
      qulotLottery,
      randomNumberGenerator,
      token,
      owner,
      treasury,
      operator,
      trigger,
      other,
      lisa,
      rose,
      bob,
      micky,
      rick,
    };
  }

  async function initLottery(
    qulotLottery: QulotLottery,
    account: SignerWithAddress,
    lottery: LotteryStruct = { ...lotteryLiteQ },
    rules: RuleStruct[] = [...lotteryLiteQRules],
  ) {
    qulotLottery = await qulotLottery.connect(account);

    // Add liteq lottery
    await (await qulotLottery.addLottery("liteq", lottery)).wait();

    // Add reward rules for liteq
    await (await qulotLottery.addRewardRules("liteq", rules)).wait();

    // Set bulkTicketsDiscountApply
    await (await qulotLottery.setBulkTicketsDiscountApply(1)).wait();

    return qulotLottery;
  }

  async function openLottery(qulotLottery: QulotLottery, account: SignerWithAddress) {
    qulotLottery = await qulotLottery.connect(account);
    await (await qulotLottery.open("liteq")).wait();
    return qulotLottery;
  }

  describe("addLottery", function () {
    describe("Validations", function () {
      it("Should fail if invalid id", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery id
        await expect(qulotLottery.connect(operator).addLottery("", { ...lotteryLiteQ })).to.revertedWith(
          "ERROR_INVALID_LOTTERY_ID",
        );
      });

      it("Should fail if invalid picture", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery picture
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            picture: "",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PICTURE");
      });

      it("Should fail if invalid verbose name", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery verbose name
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            verboseName: "",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_VERBOSE_NAME");
      });

      it("Should fail if invalid number rules", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery number of items
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            numberOfItems: "0",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS");

        // Test invalid lottery number of items less than 6
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            numberOfItems: "7",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS");

        // Test invalid lottery min value per item
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            minValuePerItem: "0",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS");

        // Test invalid lottery max value per item
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            maxValuePerItem: "0",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS");
      });

      it("Should fail if invalid period draw time", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery period days
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            periodDays: [],
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_DAYS");

        // Test invalid lottery period hour of days
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            periodHourOfDays: "25",
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS");
      });

      it("Should fail if invalid price", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);
        // Test invalid lottery price per ticket
        await expect(
          qulotLottery.connect(operator).addLottery("liteq", {
            ...lotteryLiteQ,
            pricePerTicket: parseEther("0"),
          }),
        ).to.revertedWith("ERROR_INVALID_LOTTERY_PRICE_PER_TICKET");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operator, other, treasury } = await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorTreasuryAddress(other.address, treasury.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(qulotLottery.connect(operator).addLottery("liteq", { ...lotteryLiteQ })).to.revertedWith(
          "ERROR_ONLY_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("Will match all if adding new lottery is successful", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery first
        await qulotLottery.connect(operator).addLottery("liteq", { ...lotteryLiteQ });

        // Register new lottery again, Expect error lottery already exists
        const liteq = await qulotLottery.getLottery("liteq");
        expect(liteq).to.an("array").that.includes("LiteQ");
        expect(liteq).to.an("array").that.includes("https://cdn.qulot.io/img/product-megaq.png");
        expect(await qulotLottery.getLotteryIds()).to.includes("liteq");
      });
    });

    describe("Events", function () {
      it("Should emit an event on new lottery", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery again, Expect error lottery already exists
        await expect(qulotLottery.connect(operator).addLottery("liteq", { ...lotteryLiteQ })).to.emit(
          qulotLottery,
          "NewLottery",
        );
      });
    });
  });

  describe("addRewardRules", function () {
    describe("Validations", function () {
      it("Should fail if invalid rules array", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Test invalid lottery id
        await expect(qulotLottery.connect(operator).addRewardRules("liteq", [])).to.revertedWith("ERROR_INVALID_RULES");
      });
    });

    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operator, other, treasury } = await loadFixture(deployQulotLotteryFixture);

        await qulotLottery.setOperatorTreasuryAddress(other.address, treasury.address);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery.connect(operator).addRewardRules("liteq", [
            {
              matchNumber: 3,
              rewardValue: 30,
            },
          ]),
        ).to.revertedWith("ERROR_ONLY_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Will match all if adding new rules is successful", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.connect(operator).addRewardRules("liteq", [
          {
            matchNumber: 4,
            rewardValue: 40,
          },
          {
            matchNumber: 3,
            rewardValue: 30,
          },
        ]);
        const ruleMatch1 = await qulotLottery.rulesPerLotteryId("liteq", 4);
        expect(ruleMatch1.matchNumber).to.equal(4);
        expect(ruleMatch1.rewardValue).to.equal("40");
        const ruleMatch2 = await qulotLottery.rulesPerLotteryId("liteq", 3);
        expect(ruleMatch2.matchNumber).to.equal(3);
        expect(ruleMatch2.rewardValue).to.equal("30");
      });
    });

    describe("Events", function () {
      it("Should emit an event on new rules", async function () {
        const { qulotLottery, operator } = await loadFixture(deployQulotLotteryFixture);

        // Register new lottery again, Expect error lottery already exists
        await expect(
          qulotLottery.connect(operator).addRewardRules("liteq", [
            {
              matchNumber: 4,
              rewardValue: 40,
            },
            {
              matchNumber: 3,
              rewardValue: 30,
            },
          ]),
        ).to.emit(qulotLottery, "NewRewardRule");
      });
    });
  });

  describe("open", function () {
    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operator, other, treasury } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.setOperatorTreasuryAddress(other.address, treasury.address);
        await expect(qulotLottery.connect(operator).open("liteq")).to.revertedWith("ERROR_ONLY_TRIGGER_OR_OPERATOR");
      });
    });

    describe("Data", function () {
      it("Operator cannot start a second round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.connect(fixture.trigger).open("liteq");
        await expect(qulotLottery.connect(fixture.trigger).open("liteq")).to.revertedWith(
          "ERROR_NOT_TIME_OPEN_LOTTERY",
        );
      });

      it("Will match all if open lottery successful", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operator = fixture.operator;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operator);
        await qulotLottery.open("liteq");
        expect(await qulotLottery.getRound(1)).to.haveOwnProperty("status", 0);
        expect(await qulotLottery.currentRoundIdPerLottery("liteq")).to.equal(1);
      });

      it("Test bulk open lottery, check current round id, check first round id", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operator = fixture.operator;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operator);

        for (let firstRoundId = 0; firstRoundId < 5; firstRoundId++) {
          const roundId = firstRoundId + 1;
          console.log(`Test bulk open lottery, Check round #${roundId}, first round #${firstRoundId}`);
          await qulotLottery.open("liteq");

          const currentRoundIdPerLottery = await qulotLottery.currentRoundIdPerLottery("liteq");
          console.log(`Test bulk open lottery, Current round per liteq #${currentRoundIdPerLottery}`);
          expect(currentRoundIdPerLottery).to.equal(roundId);

          const round = await qulotLottery.getRound(roundId);
          expect(round.firstRoundId).to.equal(firstRoundId);

          await qulotLottery.close("liteq");
          await qulotLottery.draw("liteq");
          await qulotLottery.reward("liteq");
        }
      });
    });

    describe("Events", function () {
      it("Should emit an event on new round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        const operator = fixture.operator;
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, operator);
        // Check event emitted
        const result = await (await qulotLottery.open("liteq")).wait();
        expect(result.events?.[0].args?.roundId).to.equal(1);
      });
    });
  });

  describe("close", function () {
    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const { qulotLottery, operator, other, treasury } = await loadFixture(deployQulotLotteryFixture);
        await qulotLottery.setOperatorTreasuryAddress(other.address, treasury.address);
        await expect(qulotLottery.connect(operator).close("liteq")).to.revertedWith("ERROR_ONLY_TRIGGER_OR_OPERATOR");
      });
    });

    describe("Data", function () {
      it("The operator can't close the lottery if he has not opened any round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        expect(await qulotLottery.close("liteq")).to.revertedWith("ERROR_NOT_TIME_CLOSE_LOTTERY");
      });
    });

    describe("Events", function () {
      it("Should emit an event on close round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.open("liteq");
        await expect(qulotLottery.close("liteq")).to.emit(qulotLottery, "RoundClose");
      });
    });
  });

  describe("draw", function () {
    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        await qulotLottery.close("liteq");
        await expect(qulotLottery.connect(fixture.other).draw("liteq")).to.revertedWith(
          "ERROR_ONLY_TRIGGER_OR_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("The operator can't draw the lottery if he has not closed any round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.connect(fixture.trigger).open("liteq");
        await expect(qulotLottery.connect(fixture.trigger).draw("liteq")).to.revertedWith(
          "ERROR_NOT_TIME_DRAW_LOTTERY",
        );
      });

      it("Should fail if invalid winning numbers", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.open("liteq");
        await qulotLottery.close("liteq");

        // Check empty winning numbers
        await fixture.randomNumberGenerator.setRandomResult("1", []);
        await expect(qulotLottery.draw("liteq")).to.revertedWith("ERROR_INVALID_WINNING_NUMBERS");

        // Check min number
        await fixture.randomNumberGenerator.setRandomResult("1", ["0", "2", "3"]);
        await expect(qulotLottery.draw("liteq")).to.revertedWith("ERROR_INVALID_WINNING_NUMBERS");

        // Check min number
        await fixture.randomNumberGenerator.setRandomResult("1", ["1", "2", "99"]);
        await expect(qulotLottery.draw("liteq")).to.revertedWith("ERROR_INVALID_WINNING_NUMBERS");
      });
    });

    describe("Events", function () {
      it("Should emit an event on draw round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.open("liteq");
        await qulotLottery.close("liteq");
        await expect(qulotLottery.draw("liteq")).to.emit(qulotLottery, "RoundDraw");
      });
    });
  });

  describe("reward", function () {
    describe("Modifiers", function () {
      it("Should fail if caller is not operator", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.open("liteq");
        await qulotLottery.close("liteq");
        await qulotLottery.draw("liteq");
        await expect(qulotLottery.connect(fixture.other).reward("liteq")).to.revertedWith(
          "ERROR_ONLY_TRIGGER_OR_OPERATOR",
        );
      });
    });

    describe("Data", function () {
      it("The operator can't reward the lottery if he has not draw any round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        await qulotLottery.connect(fixture.trigger).open("liteq");
        await expect(qulotLottery.connect(fixture.trigger).reward("liteq")).to.revertedWith(
          "ERROR_NOT_TIME_REWARD_LOTTERY",
        );
      });

      it("Check the total prize when lisa buys 3 tickets", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);

        // Lisa by 3 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: await qulotLottery.currentRoundIdPerLottery("liteq"),
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
              ["10", "4", "9"],
            ],
          },
        ]);

        expect((await qulotLottery.getRound("1")).totalAmount).equal(parseEther("2.7"));
      });

      it("Check the treasury fee when successful reward", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);

        // Lisa by 3 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: await qulotLottery.currentRoundIdPerLottery("liteq"),
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
              ["10", "4", "9"],
            ],
          },
        ]);

        await qulotLottery.connect(fixture.operator).close("liteq");
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await expect(qulotLottery.connect(fixture.operator).reward("liteq")).to.emit(qulotLottery, "RoundReward");

        const estimateTreasuryFee = (await qulotLottery.getRound("1")).totalAmount
          .mul(BigNumber.from((await qulotLottery.getLottery("liteq")).treasuryFeePercent))
          .div(BigNumber.from(100));

        expect(estimateTreasuryFee).to.equal(await fixture.token.balanceOf(fixture.treasury.address));
      });

      it("Check the amount inject when successful reward but no one wins", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);

        // Lisa by 3 tickets
        const tx = await (
          await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: await qulotLottery.currentRoundIdPerLottery("liteq"),
              tickets: [
                ["3", "5", "20"],
                ["7", "19", "52"],
                ["10", "4", "9"],
              ],
            },
          ])
        ).wait();

        console.warn("Check the amount inject when successful", tx.gasUsed);

        await qulotLottery.connect(fixture.operator).close("liteq");

        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult("1", ["1", "1", "1"]);

        await qulotLottery.connect(fixture.operator).draw("liteq");
        await expect(qulotLottery.connect(fixture.operator).reward("liteq")).to.emit(qulotLottery, "RoundReward");

        const liteq = await qulotLottery.getLottery("liteq");
        const totalRoundAmount = (await qulotLottery.getRound("1")).totalAmount;

        const estimateTreasuryFee = totalRoundAmount
          .mul(BigNumber.from(liteq.treasuryFeePercent))
          .div(BigNumber.from(100));

        const estimateAmountInject = totalRoundAmount.sub(estimateTreasuryFee);

        expect(estimateAmountInject).to.equal(await qulotLottery.amountInjectNextRoundPerLottery("liteq"));
      });

      it("Check the amount inject when successful reward, lisa win jackpot", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // Lisa by 3 tickets
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        const ticketIds = (
          await (
            await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
              {
                roundId: currentRoundId,
                tickets: [
                  ["3", "5", "20"],
                  ["7", "19", "52"],
                  ["4", "9", "10"],
                ],
              },
            ])
          ).wait()
        ).events?.find((evt) => evt.event === "MultiRoundsTicketsPurchase")?.args?.ordersResult[0]
          .ticketIds as BigNumber[];
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult("1", ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await expect(qulotLottery.connect(fixture.operator).reward("liteq")).to.emit(qulotLottery, "RoundReward");
        const liteq = await qulotLottery.getLottery("liteq");
        const totalRoundAmount = (await qulotLottery.getRound(currentRoundId)).totalAmount;
        const estimateTreasuryFee = totalRoundAmount
          .mul(BigNumber.from(liteq.treasuryFeePercent))
          .div(BigNumber.from(100));
        let estimateAmountInject = totalRoundAmount
          .mul(BigNumber.from(liteq.amountInjectNextRoundPercent))
          .div(BigNumber.from(100));
        let estimateRewardAmount = totalRoundAmount.sub(estimateTreasuryFee).sub(estimateAmountInject);
        for (const ticketId of ticketIds) {
          const ticket = await qulotLottery.getTicket(ticketId);
          if (ticket.winStatus) {
            estimateRewardAmount = estimateRewardAmount.sub(ticket.winAmount);
          }
        }
        estimateAmountInject = estimateAmountInject.add(estimateRewardAmount);
        expect(estimateAmountInject).to.equal(await qulotLottery.amountInjectNextRoundPerLottery("liteq"));
      });

      it("Check the win amount when successful reward, lisa win jackpot, rose win 2th", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // Lisa by 3 tickets
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await (
          await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [
                ["3", "5", "20"],
                ["7", "19", "52"],
                ["4", "9", "10"],
              ],
            },
          ])
        ).wait();
        await (
          await qulotLottery.connect(fixture.rose).buyTickets(fixture.rose.address, [
            {
              roundId: currentRoundId,
              tickets: [["1", "3", "5"]],
            },
          ])
        ).wait();
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await (await qulotLottery.connect(fixture.operator).reward("liteq")).wait();
        expect((await qulotLottery.getTicket("1")).winAmount).to.equal(parseEther("2.072"));
        expect((await qulotLottery.getTicket("4")).winAmount).to.equal(parseEther("0.888"));
      });

      it("Check the win amount when successful reward, lisa and rose win jackpot", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // Lisa by 3 tickets
        /**
         * total amount: 3.7
         * reward amount: total amount - (treasury fee: 10%) - (amount inject: 10%)
         *    => 3.7 - (3.7 * 10%) - (3.7 * 10%) = 2.96
         *
         * Jackpot amount:
         *    - 2 matched: 0
         *    - 3 matched: 2
         *      => reward amount - (reward amount * 70%) / winners
         *          => 2.96 * 70%) / 2 = 1.036
         *
         * Lisa win 1.036, Rose win 1.036
         */
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await (
          await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [
                ["3", "5", "20"],
                ["7", "19", "52"],
                ["4", "9", "10"],
              ],
            },
          ])
        ).wait();
        await (
          await qulotLottery.connect(fixture.rose).buyTickets(fixture.rose.address, [
            {
              roundId: currentRoundId,
              tickets: [["3", "5", "20"]],
            },
          ])
        ).wait();
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await (await qulotLottery.connect(fixture.operator).reward("liteq")).wait();
        expect((await qulotLottery.getTicket("1")).winAmount).to.equal(parseEther("1.036"));
        expect((await qulotLottery.getTicket("4")).winAmount).to.equal(parseEther("1.036"));
      });

      it("Check the win amount when successful reward, micky and rick win 3th", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // micky by 3 tickets
        // rick by 3 tickets
        /**
         * total amount: 5.4
         * reward amount: total amount - (treasury fee: 10%) - (amount inject: 10%)
         *    => 5.4 - (5.4 * 10%) - (5.4 * 10%) = 4.32
         *
         * Jackpot amount:
         *    - 2 matched: 2
         *      => reward amount - (reward amount * 70%) / winners
         *          => 4.32 * 30% / 2 = 0.648
         *    - 3 matched: 0
         *
         * micky win 0.648, rick win 0.648
         */
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await qulotLottery.connect(fixture.micky).buyTickets(fixture.micky.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "10"],
              ["7", "19", "52"],
              ["4", "9", "10"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.rick).buyTickets(fixture.rick.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["1", "5", "20"],
              ["1", "2", "3"],
              ["4", "10", "30"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await (await qulotLottery.connect(fixture.operator).reward("liteq")).wait();
        expect((await qulotLottery.getTicket("1")).winAmount).to.equal(parseEther("0.648"));
        expect((await qulotLottery.getTicket("4")).winAmount).to.equal(parseEther("0.648"));
      });

      it("Check the win amount when successful reward, lisa and rose win jackpot, micky and rick win 3th", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(
          qulotLottery,
          fixture.operator,
          { ...lotteryLiteQ, maxNumberTicketsPerBuy: 5 },
          [
            {
              matchNumber: 3,
              rewardValue: 50,
            },
            {
              matchNumber: 2,
              rewardValue: 30,
            },
            {
              matchNumber: 1,
              rewardValue: 20,
            },
          ],
        );
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // Lisa by 3 tickets = 2.7
        // Rose by 5 tickets = 4.5
        // Micky by 1 tickets = 1
        // Rick by 2 tickets = 1.8
        /**
         * total amount: 10
         * reward amount: total amount - (treasury fee: 10%) - (amount inject: 10%)
         *    => 10 - (10 * 10%) - (10 * 10%) = 8
         *
         * Jackpot amount:
         *    - 1 matched: 4
         *      => reward amount - (reward amount * 20%) / winners
         *          => 8 * 20% / 4 = 0.4
         *    - 2 matched: 0
         *    - 3 matched: 2
         *      => reward amount - (reward amount * 70%) / winners
         *          => 8 * 50% / 2 = 2
         *
         * Lisa win 1.036, Rose win 1.036
         */
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"], // ==> 3 matched
              ["7", "19", "52"],
              ["4", "9", "10"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.rose).buyTickets(fixture.rose.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"], // ==> 3 matched
              ["12", "15", "20"], // ==> 1 matched
              ["9", "11", "18"],
              ["7", "8", "19"],
              ["1", "2", "3"], // ==> 1 matched
            ],
          },
        ]);
        await (
          await qulotLottery.connect(fixture.micky).buyTickets(fixture.micky.address, [
            {
              roundId: currentRoundId,
              tickets: [["3", "9", "50"]], // ==> 1 matched
            },
          ])
        ).wait();
        await (
          await qulotLottery.connect(fixture.rick).buyTickets(fixture.rick.address, [
            {
              roundId: currentRoundId,
              tickets: [
                ["3", "30", "40"], // ==> 1 matched
                ["11", "12", "13"],
              ],
            },
          ])
        ).wait();
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await (await qulotLottery.connect(fixture.operator).reward("liteq")).wait();
        const winJackpotTicketIds = [1, 4];
        const win3thTicketIds = [5, 8, 9, 10];
        const ticketLength = (await qulotLottery.getTicketsLength()).toNumber();
        for (const ticketId of Array.from({ length: ticketLength }, (_, i) => i + 1)) {
          const ticket = await qulotLottery.getTicket(ticketId);
          if (winJackpotTicketIds.includes(ticketId)) {
            expect(ticket.winAmount).to.equal(parseEther("2"));
            continue;
          }
          if (win3thTicketIds.includes(ticketId)) {
            expect(ticket.winAmount).to.equal(parseEther("0.4"));
            continue;
          }
          expect(ticket.winStatus).to.equal(false);
        }
      });

      // it("Should fail if gas used out 1.5 million unit for 100 tickets", async function () {
      //   const fixture = await loadFixture(deployQulotLotteryFixture);
      //   let qulotLottery = fixture.qulotLottery;
      //   qulotLottery = await initLottery(qulotLottery, fixture.operator, {
      //     ...lotteryLiteQ,
      //     maxNumberTicketsPerBuy: "100",
      //     maxNumberTicketsPerRound: "100",
      //   });
      //   qulotLottery = await openLottery(qulotLottery, fixture.operator);

      //   const liteq = await qulotLottery.getLottery("liteq");
      //   // Lisa by 3 tickets
      //   const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");

      //   const bulkTickets = Array(99)
      //     .fill(0)
      //     .map(() => bulkRandomRange(liteq.numberOfItems, liteq.minValuePerItem, liteq.maxValuePerItem));
      //   await (
      //     await qulotLottery.connect(fixture.lisa).buyTickets(
      //       [
      //         {
      //           roundId: currentRoundId,
      //           tickets: [...bulkTickets, ["3", "5", "20"]],
      //         },
      //       ],
      //       { gasLimit: 999999999 },
      //     )
      //   ).wait();
      //   await qulotLottery.connect(fixture.operator).close("liteq");
      //   // Mock winning numbers for lisa jackpot
      //   await fixture.randomNumberGenerator.setRandomResult("1", ["3", "5", "20"]);
      //   await qulotLottery.connect(fixture.operator).draw("liteq");
      //   const tx = await (await qulotLottery.connect(fixture.operator).reward("liteq")).wait();
      //   console.warn(`Reward gas used: ${tx.gasUsed}`);
      //   expect(tx.gasUsed.toNumber()).to.lt(1500000);
      // });
    });

    describe("Events", function () {
      it("Should emit an event on reward round", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        // Lisa by 3 tickets
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
              ["10", "4", "9"],
            ],
          },
        ]);
        // Mock no one wins
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["1", "1", "1"]);
        await qulotLottery.connect(fixture.operator).close("liteq");
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await expect(qulotLottery.connect(fixture.operator).reward("liteq")).to.emit(qulotLottery, "RoundReward");
      });
    });
  });

  describe("buyTickets", function () {
    describe("Validations", function () {
      it("Should fail if round not opened", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        await qulotLottery.close("liteq");
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await expect(
          qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [["1", "3", "4"]],
            },
          ]),
        ).to.revertedWith("ERROR_ROUND_IS_CLOSED");
      });
      it("Should fail if round is larger than current", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await expect(
          qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId.add(BigNumber.from(1)),
              tickets: [["1", "3", "4"]],
            },
          ]),
        ).to.revertedWith("ERROR_ROUND_IS_CLOSED");
      });
      it("Should fail if tickets empty", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await expect(
          qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [],
            },
          ]),
        ).to.revertedWith("ERROR_TICKETS_EMPTY");
      });
      it("Should fail if tickets out of limit", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await expect(
          qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [
                ["1", "3", "4"],
                ["1", "3", "4"],
                ["1", "3", "4"],
                ["1", "3", "4"],
                ["1", "3", "4"],
              ],
            },
          ]),
        ).to.revertedWith("ERROR_TICKETS_LIMIT");
      });
    });

    describe("Data", function () {
      it("Should fail if gas used is too high", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        const tx = await (
          await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [["3", "5", "20"]],
            },
          ])
        ).wait();
        console.warn(`buyTickets gas used: ${tx.gasUsed}`);
        expect(tx.gasUsed.toNumber()).to.lt(1200000);
      });

      it("Check lottery total tickets, total prize", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["1", "3", "4"],
              ["5", "6", "7"],
              ["8", "9", "10"],
            ],
          },
        ]);
        // Mock rose by 2 tickets
        await qulotLottery.connect(fixture.rose).buyTickets(fixture.rose.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["7", "3", "9"],
              ["1", "7", "3"],
            ],
          },
        ]);
        const round = await qulotLottery.getRound(currentRoundId);
        expect(round.totalTickets).to.equal(5);
        expect(round.totalAmount).to.equal(parseEther("4.5"));
      });

      it("Check ticket state if successful purchased", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        const ticketIds = (
          await (
            await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
              {
                roundId: currentRoundId,
                tickets: [
                  ["3", "5", "20"],
                  ["7", "19", "52"],
                  ["10", "4", "9"],
                ],
              },
            ])
          ).wait()
        ).events?.find((evt) => evt.event === "MultiRoundsTicketsPurchase")?.args?.ordersResult[0]
          .ticketIds as BigNumber[];
        for (const ticketId of ticketIds) {
          const ticket = await qulotLottery.getTicket(ticketId);
          expect(ticket.owner).equal(fixture.lisa.address);
          expect(ticket.winAmount).equal("0");
          expect(ticket.winStatus).equal(false);
          expect(ticket.winRewardRule).equal("0");
          expect(ticket.clamStatus).equal(false);
        }
      });

      it("Check lisa buy 3 tickets for rose", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        const txnLogMultiRoundsTicketsPurchase = (
          await (
            await qulotLottery.connect(fixture.lisa).buyTickets(fixture.rose.address, [
              {
                roundId: currentRoundId,
                tickets: [
                  ["3", "5", "20"],
                  ["7", "19", "52"],
                  ["10", "4", "9"],
                ],
              },
            ])
          ).wait()
        ).events?.find((evt) => evt.event === "MultiRoundsTicketsPurchase");
        const ticketIds = txnLogMultiRoundsTicketsPurchase?.args?.ordersResult[0].ticketIds as BigNumber[];
        for (const ticketId of ticketIds) {
          const ticket = await qulotLottery.getTicket(ticketId);
          expect(ticket.owner).equal(fixture.rose.address);
          expect(ticket.winAmount).equal("0");
          expect(ticket.winStatus).equal(false);
          expect(ticket.winRewardRule).equal("0");
          expect(ticket.clamStatus).equal(false);
        }
      });
    });

    describe("Events", function () {
      it("Should emit an event on successful ticket purchase", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        await expect(
          qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
            {
              roundId: currentRoundId,
              tickets: [
                ["3", "5", "20"],
                ["7", "19", "52"],
                ["10", "4", "9"],
              ],
            },
          ]),
        ).to.emit(qulotLottery, "MultiRoundsTicketsPurchase");
      });
    });
  });

  describe("claimTickets", function () {
    describe("Validations", function () {
      it("Should fail if tickets claim is empty", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        await expect(qulotLottery.claimTickets([])).to.revertedWith("ERROR_TICKETS_EMPTY");
      });
    });

    describe("Data", function () {
      it("Should fail if the owner of ticket is not sender", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        const ticketIds = (
          await (
            await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
              {
                roundId: currentRoundId,
                tickets: [
                  ["3", "5", "20"],
                  ["7", "19", "52"],
                ],
              },
            ])
          ).wait()
        ).events?.find((evt) => evt.event === "MultiRoundsTicketsPurchase")?.args?.ordersResult[0]
          .ticketIds as BigNumber[];
        await qulotLottery.close("liteq");
        await qulotLottery.draw("liteq");
        await qulotLottery.reward("liteq");
        await expect(qulotLottery.connect(fixture.rose).claimTickets(ticketIds)).to.revertedWith("ERROR_ONLY_OWNER");
      });

      it("Should fail if the owner of ticket is not win", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        const ticketIds = (
          await (
            await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
              {
                roundId: currentRoundId,
                tickets: [
                  ["3", "5", "20"],
                  ["7", "19", "52"],
                ],
              },
            ])
          ).wait()
        ).events?.find((evt) => evt.event === "MultiRoundsTicketsPurchase")?.args?.ordersResult[0]
          .ticketIds as BigNumber[];
        await qulotLottery.close("liteq");
        // Mock winning numbers for lisa never win
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["1", "2", "3"]);
        await qulotLottery.draw("liteq");
        await qulotLottery.reward("liteq");
        await expect(qulotLottery.connect(fixture.lisa).claimTickets(ticketIds)).to.revertedWith(
          "ERROR_TICKET_NOT_WIN",
        );
      });

      it("Should fail if the sender claim ticket again", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 3 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa win jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await qulotLottery.connect(fixture.operator).reward("liteq");
        // Lisa claim first time
        await qulotLottery.connect(fixture.lisa).claimTickets(["1"]);
        // Check lisa claim again
        await expect(qulotLottery.connect(fixture.lisa).claimTickets(["1"])).to.revertedWith(
          "ERROR_ONLY_CLAIM_PRIZE_ONCE",
        );
      });

      it("Check user balance after claim tickets", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 2 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa win jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await qulotLottery.connect(fixture.operator).reward("liteq");

        // Check lisa claim
        await expect(qulotLottery.connect(fixture.lisa).claimTickets(["1"])).to.changeTokenBalances(
          fixture.token,
          [qulotLottery.address, fixture.lisa.address],
          [parseEther("-1.008"), parseEther("1.008")],
        );
      });
    });

    describe("Events", function () {
      it("Should emit an event on successful ticket claim", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");
        // Mock lisa by 2 tickets
        await qulotLottery.connect(fixture.lisa).buyTickets(fixture.lisa.address, [
          {
            roundId: currentRoundId,
            tickets: [
              ["3", "5", "20"],
              ["7", "19", "52"],
            ],
          },
        ]);
        await qulotLottery.connect(fixture.operator).close("liteq");
        // Mock winning numbers for lisa win jackpot
        await fixture.randomNumberGenerator.setRandomResult(currentRoundId, ["3", "5", "20"]);
        await qulotLottery.connect(fixture.operator).draw("liteq");
        await qulotLottery.connect(fixture.operator).reward("liteq");

        // Check lisa claim
        await expect(qulotLottery.connect(fixture.lisa).claimTickets(["1"])).to.emit(qulotLottery, "TicketsClaim");
      });
    });
  });

  describe("calculateAmountForBulkTickets", function () {
    describe("Data", function () {
      it("Check calculate total price for bulk tickets ok", async function () {
        const fixture = await loadFixture(deployQulotLotteryFixture);
        let qulotLottery = fixture.qulotLottery;
        // Register new lottery first
        qulotLottery = await initLottery(qulotLottery, fixture.operator);
        qulotLottery = await openLottery(qulotLottery, fixture.operator);
        const currentRoundId = await qulotLottery.currentRoundIdPerLottery("liteq");

        let result = await qulotLottery.calculateAmountForBulkTickets(currentRoundId, 1);
        expect(result.totalAmount).to.eq(parseEther("1"));
        expect(result.finalAmount).to.eq(parseEther("1"));
        expect(result.discount).to.eq(parseEther("0"));
        result = await qulotLottery.calculateAmountForBulkTickets(currentRoundId, 3);
        expect(result.totalAmount).to.eq(parseEther("3"));
        expect(result.finalAmount).to.eq(parseEther("2.7"));
        expect(result.discount.toNumber()).to.eq(10);
      });
    });
  });
});
