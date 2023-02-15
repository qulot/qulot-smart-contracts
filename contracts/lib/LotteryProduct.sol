// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct LotteryProduct {
    string verboseName;
    string picture;
    uint32 numberOfItems;
    uint32 minValuePerItem;
    uint32 maxValuePerItem;
    uint[] periodDays;
    uint periodHourOfDays;
    uint maxNumberTicketsPerBuy;
    uint256 pricePerTicket;
}
