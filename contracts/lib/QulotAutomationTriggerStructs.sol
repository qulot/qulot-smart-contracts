// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { JobType } from "./QulotAutomationTriggerEnums.sol";

struct TriggerJob {
    string lotteryId;
    JobType jobType;
    bool isExists;
}
