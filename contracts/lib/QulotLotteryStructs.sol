// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { RoundStatus } from "./QulotLotteryEnums.sol";

struct Lottery {
    string verboseName;
    string picture;
    uint32 numberOfItems;
    uint32 minValuePerItem;
    uint32 maxValuePerItem;
    // day of the week (0 - 6) (Sunday-to-Saturday)
    uint[] periodDays;
    // hour (0 - 23)
    uint periodHourOfDays;
    uint32 maxNumberTicketsPerBuy;
    uint256 pricePerTicket;
    uint32 treasuryFeePercent;
    uint32 amountInjectNextRoundPercent;
    uint32 discountPercent;
    uint256 maxNumberTicketsPerRound;
}

struct Round {
    string lotteryId;
    uint32[] winningNumbers;
    uint256 endTime;
    uint256 openTime;
    uint256 totalAmount;
    uint256 totalTickets;
    uint256 firstRoundId;
    RoundStatus status;
    mapping(uint => uint32) winningNumberPerIndexed;
}

struct RoundView {
    string lotteryId;
    uint32[] winningNumbers;
    uint256 endTime;
    uint256 openTime;
    uint256 totalAmount;
    uint256 totalTickets;
    uint256 firstRoundId;
    RoundStatus status;
}

struct Rule {
    uint matchNumber;
    uint256 rewardValue;
}

struct Ticket {
    uint256 ticketId;
    uint32[] numbers;
    address owner;
    uint256 roundId;
    bool winStatus;
    uint winRewardRule;
    bool clamStatus;
    mapping(uint32 => bool) contains;
}

struct TicketView {
    uint256 ticketId;
    uint32[] numbers;
    address owner;
    uint256 roundId;
    bool winStatus;
    uint winRewardRule;
    uint256 winAmount;
    bool clamStatus;
}

struct OrderTicket {
    uint256 roundId;
    uint32[][] tickets;
}

struct OrderTicketResult {
    uint256 orderId;
    uint256 roundId;
    uint256[] ticketIds;
    uint256 orderAmount;
    uint256 timestamp;
}
