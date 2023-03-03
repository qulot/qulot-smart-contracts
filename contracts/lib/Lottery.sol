// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct Lottery {
    string verboseName;
    string picture;
    uint32 numberOfItems;
    uint32 minValuePerItem;
    uint32 maxValuePerItem;
    uint[] periodDays;
    uint periodHourOfDays;
    uint32 maxNumberTicketsPerBuy;
    uint256 pricePerTicket;
    uint32 treasuryFeePercent;
    uint256 totalPrize;
    uint256 totalTickets;
}
