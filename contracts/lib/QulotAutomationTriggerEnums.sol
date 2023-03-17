// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

enum JobType {
    TriggerOpenLottery,
    TriggerCloseLottery,
    TriggerDrawLottery,
    TriggerRewardLottery
}

enum JobStatus {
    Success,
    Error
}
