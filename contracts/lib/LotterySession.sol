// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SessionStatus} from "./Enums.sol";

struct LotterySession {
    uint32[] winningNumbers;
    uint256 drawDateTime;
    uint256 openTime;
    uint256 totalAmount;
    SessionStatus status;
}
