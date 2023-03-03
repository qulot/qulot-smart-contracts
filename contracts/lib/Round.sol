// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {RoundStatus} from "./Enums.sol";

struct Round {
    uint32[] winningNumbers;
    uint256 drawDateTime;
    uint256 openTime;
    uint256 totalAmount;
    RoundStatus status;
}
