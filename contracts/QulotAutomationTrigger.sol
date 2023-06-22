// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import { Cron, Spec } from "@chainlink/contracts/src/v0.8/libraries/internal/Cron.sol";
import { IQulotLottery } from "./interfaces/IQulotLottery.sol";
import { IQulotAutomationTrigger } from "./interfaces/IQulotAutomationTrigger.sol";
import { String } from "./utils/StringUtils.sol";
import { JobType, JobStatus } from "./lib/QulotAutomationTriggerEnums.sol";
import { TriggerJob } from "./lib/QulotAutomationTriggerStructs.sol";

string constant ERROR_ONLY_OPERATOR = "ERROR_ONLY_OPERATOR";
string constant ERROR_INVALID_ZERO_ADDRESS = "ERROR_INVALID_ZERO_ADDRESS";
string constant ERROR_INVALID_JOB_ID = "ERROR_INVALID_JOB_ID";
string constant ERROR_INVALID_LOTTERY_ID = "ERROR_INVALID_LOTTERY_ID";
string constant ERROR_INVALID_JOB_CRON_SPEC = "ERROR_INVALID_JOB_CRON_SPEC";
string constant ERROR_TRIGGER_JOB_ALREADY_EXISTS = "ERROR_TRIGGER_JOB_ALREADY_EXISTS";

contract QulotAutomationTrigger is IQulotAutomationTrigger, AutomationCompatibleInterface, Ownable {
    using Counters for Counters.Counter;
    using Cron for Spec;

    error TickInFuture();
    error TickTooOld();
    error TickDoesntMatchSpec();
    event NewTriggerJob(string jobId, string lotteryId, JobType jobType, string cronSpec);
    event PerformTriggerJob(string jobId, uint256 timestamp, JobStatus status);

    IQulotLottery public qulotLottery;
    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    mapping(string => uint256) public lastRuns;

    // Keep track of job id for a given jobId
    mapping(string => TriggerJob) private jobs;
    mapping(string => Spec) private specs;
    string[] private jobIds;

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, ERROR_ONLY_OPERATOR);
        _;
    }

    /**
     * @notice method that is simulated by the keepers to see if any work actually
     * needs to be performed. This method does does not actually need to be
     * executable, and since it is only ever simulated it can consume lots of gas.
     * @return upkeepNeeded boolean to indicate whether the keeper should call
     * performUpkeep or not.
     * @return performData bytes that the keeper should call performUpkeep with, if
     * upkeep is needed. If you would like to encode data to decode later, try
     * `abi.encode`.
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // DEV: start at a random spot in the list so that checks are
        // spread evenly among cron jobs
        uint256 numCrons = jobIds.length;
        if (numCrons == 0) {
            return (false, bytes(""));
        }
        uint256 startIdx = block.number % numCrons;
        bool result;
        bytes memory payload;
        (result, payload) = checkInRange(startIdx, numCrons);
        if (result) {
            return (result, payload);
        }
        (result, payload) = checkInRange(0, startIdx);
        if (result) {
            return (result, payload);
        }
        return (false, bytes(""));
    }

    /**
     * @notice checks the cron jobs in a given range
     * @param start the starting id to check (inclusive)
     * @param end the ending id to check (exclusive)
     * @return upkeepNeeded signals if upkeep is needed, performData is an abi encoding
     * of the id and "next tick" of the eligible cron job
     */
    function checkInRange(uint start, uint end) private view returns (bool, bytes memory) {
        string memory id;
        uint256 timestamp = _removeTimestampSeconds(block.timestamp);
        for (uint256 idx = start; idx < end; idx++) {
            id = jobIds[idx];
            if (specs[id].matches(timestamp)) {
                return (true, abi.encode(id));
            }
        }
        return (false, bytes(""));
    }

    /**
     * @notice method that is actually executed by the keepers, via the registry.
     * The data returned by the checkUpkeep simulation will be passed into
     * this method to actually be executed.
     * @param performData is the data which was passed back from the checkData
     * simulation. If it is encoded, it can easily be decoded into other types by
     * calling `abi.decode`. This data should not be trusted, and should be
     * validated against the contract's current state.
     */
    function performUpkeep(bytes calldata performData) external override {
        string memory jobId = abi.decode(performData, (string));
        excuteJob(jobId);
    }

    /**
     * @notice Execute trigger job by job id
     * @param jobId The id of the trigger job
     * @dev Callable by internal
     */
    function excuteJob(string memory jobId) internal {
        lastRuns[jobId] = block.timestamp;
        TriggerJob memory job = jobs[jobId];

        if (job.jobType == JobType.TriggerOpenLottery) {
            qulotLottery.open(job.lotteryId);
        } else if (job.jobType == JobType.TriggerCloseLottery) {
            qulotLottery.close(job.lotteryId);
        } else if (job.jobType == JobType.TriggerDrawLottery) {
            qulotLottery.draw(job.lotteryId);
        } else if (job.jobType == JobType.TriggerRewardLottery) {
            qulotLottery.reward(job.lotteryId);
        }

        emit PerformTriggerJob(jobId, block.timestamp, JobStatus.Success);
    }

    /**
     * @notice Add more trigger job
     * @param _jobId Id of cron job
     * @param _lotteryId Id of lottery want scheduled
     * @param _jobCronSpec Spec of crontab
     * @param _jobType Job type
     * @dev Callable by operator
     */
    function addTriggerJob(
        string memory _jobId,
        string memory _lotteryId,
        string memory _jobCronSpec,
        JobType _jobType
    ) external override onlyOperator {
        require(!String.isEmpty(_jobId), ERROR_INVALID_JOB_ID);
        require(!jobs[_jobId].isExists, ERROR_TRIGGER_JOB_ALREADY_EXISTS);
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(!String.isEmpty(_jobCronSpec), ERROR_INVALID_JOB_CRON_SPEC);

        jobs[_jobId] = TriggerJob({ lotteryId: _lotteryId, jobType: _jobType, isExists: true });
        specs[_jobId] = Cron.toSpec(_jobCronSpec);
        jobIds.push(_jobId);
        lastRuns[_jobId] = block.timestamp;

        emit NewTriggerJob(_jobId, _lotteryId, _jobType, _jobCronSpec);
    }

    /**
     * @notice Return a list of job ids
     */
    function getJobIds() external view returns (string[] memory) {
        return jobIds;
    }

    /**
     * @notice Return trigger job by job id
     * @param _jobId The id of the trigger job
     */
    function getJob(string memory _jobId) external view returns (TriggerJob memory) {
        return jobs[_jobId];
    }

    /**
     * @notice Return crontab, last tick, next tick by job id
     * @param _jobId The id of the trigger job
     */
    function getJobTick(string memory _jobId) external view returns (string memory, uint256, uint256) {
        return (specs[_jobId].toCronString(), specs[_jobId].lastTick(), specs[_jobId].nextTick());
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLotteryAddress: address of the Qulot lottery
     * @dev Callable by owner
     */
    function setQulotLottery(address _qulotLotteryAddress) external override onlyOwner {
        qulotLottery = IQulotLottery(_qulotLotteryAddress);
    }

    /**
     *
     * @param _operatorAddress The lottery scheduler account used to run regular operations.
     * @dev Callable by owner
     */
    function setOperatorAddress(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), ERROR_INVALID_ZERO_ADDRESS);
        operatorAddress = _operatorAddress;
    }

    /**
     * @notice Remove seconds from timestamp
     * @param _timestamp timestamp
     */
    function _removeTimestampSeconds(uint256 _timestamp) private pure returns (uint256) {
        return _timestamp - (_timestamp % 60);
    }
}
