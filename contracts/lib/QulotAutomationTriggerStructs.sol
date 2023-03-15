// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Spec } from "@chainlink/contracts/src/v0.8/libraries/internal/Cron.sol";
import { JobType } from "./QulotAutomationTriggerEnums.sol";

struct TriggerJob {
    string lotteryId;
    Spec cronSpec;
    uint256 lastRun;
    JobType jobType;
}
