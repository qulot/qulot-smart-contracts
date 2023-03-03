// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {RewardUnit} from "./Enums.sol";

struct Rule {
    uint32 matchNumber;
    RewardUnit rewardUnit;
    uint256 rewardValue;
}
