// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { JobType } from "../lib/QulotAutomationTriggerEnums.sol";

interface IQulotAutomationTrigger {
    /**
     * @notice Add more trigger job
     * @param _jobId Id of cron job
     * @param _lotteryId Id of lottery want scheduled
     * @param _jobCronSpec Spec of crontab
     * @param _jobType Job type
     */
    function addTriggerJob(
        string memory _jobId,
        string memory _lotteryId,
        string memory _jobCronSpec,
        JobType _jobType
    ) external;

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setQulotLottery(address _qulotLottery) external;

    /**
     * @notice Remove trigger job
     * @param _jobId Id of cron job
     */
    function removeTriggerJob(string memory _jobId) external;
}
