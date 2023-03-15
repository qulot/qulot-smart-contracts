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
import { JobType } from "./lib/QulotAutomationTriggerEnums.sol";
import { TriggerJob } from "./lib/QulotAutomationTriggerStructs.sol";

contract QulotAutomationTrigger is IQulotAutomationTrigger, AutomationCompatibleInterface, Ownable {
    using Counters for Counters.Counter;
    using Cron for Spec;

    error TickInFuture();
    error TickTooOld();
    error TickDoesntMatchSpec();
    event NewTriggerJob(string jobId, string lotteryId, JobType jobType, string cronSpec);

    string private constant ERROR_ONLY_OPERATOR = "ERROR_ONLY_OPERATOR";
    string private constant ERROR_INVALID_ZERO_ADDRESS = "ERROR_INVALID_ZERO_ADDRESS";
    string private constant ERROR_INVALID_LOTTERY_ID = "ERROR_INVALID_LOTTERY_ID";
    string private constant ERROR_INVALID_JOB_ID = "ERROR_INVALID_LOTTERY_ID";
    string private constant ERROR_INVALID_JOB_CRON_SPEC = "ERROR_INVALID_JOB_CRON_SPEC";

    IQulotLottery public qulotLottery;
    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;

    // Keep track of job id for a given jobId
    mapping(string => TriggerJob) private _jobs;
    string[] private _jobIds;

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
        if (_jobIds.length == 0) {
            return (false, bytes(""));
        }

        for (uint i = 0; i < _jobIds.length; i++) {
            string memory jobId = _jobIds[i];
            uint256 lastTick = _jobs[jobId].cronSpec.lastTick();
            if (lastTick > _jobs[jobId].lastRun) {
                return (true, abi.encode(jobId, lastTick));
            }
        }
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
        (string memory jobId, uint256 tickTime) = abi.decode(performData, (string, uint256));
        validate(jobId, tickTime);
        _jobs[jobId].lastRun = block.timestamp;

        TriggerJob memory job = _jobs[jobId];
        if (job.jobType == JobType.TriggerOpenLottery) {
            qulotLottery.open(job.lotteryId, job.cronSpec.nextTick());
        } else if (job.jobType == JobType.TriggerCloseLottery) {
            qulotLottery.close(job.lotteryId);
        } else if (job.jobType == JobType.TriggerDrawLottery) {
            qulotLottery.draw(job.lotteryId);
        }
    }

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
    ) external override onlyOperator {
        require(!String.isEmpty(_jobId), ERROR_INVALID_JOB_ID);
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(!String.isEmpty(_jobCronSpec), ERROR_INVALID_JOB_CRON_SPEC);

        _jobs[_jobId] = TriggerJob({
            lotteryId: _lotteryId,
            cronSpec: Cron.toSpec(_jobCronSpec),
            jobType: _jobType,
            lastRun: block.timestamp
        });
        _jobIds.push(_jobId);

        emit NewTriggerJob(_jobId, _lotteryId, _jobType, _jobCronSpec);
    }

    /**
     * @notice Return a list of job ids
     */
    function getJobIds() external view returns (string[] memory) {
        return _jobIds;
    }

    /**
     * @notice Return trigger job by job id
     * @param _jobId The id of the trigger job
     */
    function getJob(string memory _jobId) external view returns (TriggerJob memory) {
        return _jobs[_jobId];
    }

    /**
     * @notice Validates the input to performUpkeep
     * @param _jobId The id of the trigger job
     * @param _tickTime The observed tick time
     */
    function validate(string memory _jobId, uint256 _tickTime) internal view {
        _tickTime = _tickTime - (_tickTime % 60); // remove seconds from tick time
        if (block.timestamp < _tickTime) {
            revert TickInFuture();
        }
        if (_tickTime <= _jobs[_jobId].lastRun) {
            revert TickTooOld();
        }
        if (!Cron.matches(_jobs[_jobId].cronSpec, _tickTime)) {
            revert TickDoesntMatchSpec();
        }
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLotteryAddress: address of the Qulot lottery
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
}
