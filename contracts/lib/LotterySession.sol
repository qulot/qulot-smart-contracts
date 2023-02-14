// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SessionStatus} from "./Enums.sol";

struct LotterySession {
    uint256 sessionId;
    string productId;
    uint32[] winningNumbers;
    uint256 drawDateTime;
    uint256 amount;
    SessionStatus status;
}
