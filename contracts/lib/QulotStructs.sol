// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { RoundStatus, RewardUnit } from "./QulotEnums.sol";

struct Lottery {
    string verboseName;
    string picture;
    uint32 numberOfItems;
    uint32 minValuePerItem;
    uint32 maxValuePerItem;
    // day of the week (1 - 7) (Monday to Sunday)
    uint[] periodDays;
    // hour (0 - 23)
    uint periodHourOfDays;
    uint32 maxNumberTicketsPerBuy;
    uint256 pricePerTicket;
    uint32 treasuryFeePercent;
    uint32 amountInjectNextRoundPercent;
    uint256 totalPrize;
    uint256 totalTickets;
}

struct Round {
    uint32[] winningNumbers;
    uint256 drawDateTime;
    uint256 openTime;
    uint256 totalAmount;
    uint256 firstRoundId;
    RoundStatus status;
}

struct Rule {
    uint32 matchNumber;
    RewardUnit rewardUnit;
    uint256 rewardValue;
}

struct Ticket {
    uint32[] numbers;
    address owner;
}
