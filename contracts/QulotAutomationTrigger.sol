// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import { Cron, Spec } from "@chainlink/contracts/src/v0.8/libraries/internal/Cron.sol";
import { IQulotLottery } from "./interfaces/IQulotLottery.sol";

contract QulotAutomationTrigger is AutomationCompatibleInterface, Ownable {
    using Counters for Counters.Counter;
    using Cron for Spec;

    enum JobType {
        TriggerOpenLottery,
        TriggerCloseLottery,
        TriggerClaimLottery
    }

    struct TriggerJob {
        string lotteryId;
        Spec cronSpec;
        uint256 lastRun;
        JobType jobType;
    }

    error TickInFuture();
    error TickTooOld();
    error TickDoesntMatchSpec();

    IQulotLottery public qulotLottery;
    mapping(string => TriggerJob) public jobs;
    string[] public jobIds;

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if (jobIds.length == 0) {
            return (false, bytes(""));
        }

        for (uint i = 0; i < jobIds.length; i++) {
            string memory jobId = jobIds[i];
            uint256 lastTick = jobs[jobId].cronSpec.lastTick();
            if (lastTick > jobs[jobId].lastRun) {
                return (true, abi.encode(jobId, lastTick));
            }
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (string memory jobId, uint256 tickTime) = abi.decode(performData, (string, uint256));
        validate(jobId, tickTime);
        jobs[jobId].lastRun = block.timestamp;

        TriggerJob memory job = jobs[jobId];
        if (job.jobType == JobType.TriggerOpenLottery) {
            qulotLottery.open(job.lotteryId, job.cronSpec.nextTick());
        } else if (job.jobType == JobType.TriggerCloseLottery) {
            qulotLottery.close(job.lotteryId);
        } else if (job.jobType == JobType.TriggerCloseLottery) {
            qulotLottery.draw(job.lotteryId);
        }
    }

    /**
     * @notice Validates the input to performUpkeep
     * @param jobId The id of the cron job
     * @param tickTime The observed tick time
     */
    function validate(string memory jobId, uint256 tickTime) internal view {
        tickTime = tickTime - (tickTime % 60); // remove seconds from tick time
        if (block.timestamp < tickTime) {
            revert TickInFuture();
        }
        if (tickTime <= jobs[jobId].lastRun) {
            revert TickTooOld();
        }
        if (!Cron.matches(jobs[jobId].cronSpec, tickTime)) {
            revert TickDoesntMatchSpec();
        }
    }

    function setQulotLottery(address _qulotLotteryAddress) external onlyOwner {
        qulotLottery = IQulotLottery(_qulotLotteryAddress);
    }
}
