// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { RewardUnit } from "../lib/QulotEnums.sol";

interface IQulotLottery {
    /**
     * @notice Change the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     * @dev Callable by operator
     */
    function changeRandomGenerator(address _randomGeneratorAddress) external;

    /**
     *
     * @notice Add new lottery. Only call when deploying smart contact for the first time
     * @param _lotteryId lottery id
     * @param _picture Lottery picture
     * @param _verboseName Verbose name of lottery
     * @param _numberOfItems Numbers on the ticket
     * @param _minValuePerItem Min value per number on the ticket
     * @param _maxValuePerItem Max value per number on the ticket
     * @param _periodDays Daily period of round
     * @param _periodHourOfDays Hourly period of round
     * @param _maxNumberTicketsPerBuy Maximum number of tickets that can be purchased
     * @param _pricePerTicket Price per ticket
     * @param _treasuryFeePercent Treasury fee
     * @param _amountInjectNextRoundPercent Amount inject for next round
     * @dev Callable by operator
     */
    function addLottery(
        string memory _lotteryId,
        string memory _picture,
        string memory _verboseName,
        uint32 _numberOfItems,
        uint32 _minValuePerItem,
        uint32 _maxValuePerItem,
        uint[] memory _periodDays,
        uint _periodHourOfDays,
        uint32 _maxNumberTicketsPerBuy,
        uint256 _pricePerTicket,
        uint32 _treasuryFeePercent,
        uint32 _amountInjectNextRoundPercent
    ) external;

    /**
     * @notice Add more rule reward for lottery payout. Only call when deploying smart contact for the first time
     * @param _lotteryId Lottery id
     * @param _matchNumber Number match
     * @param _rewardUnit Reward unit
     * @param _rewardValue Reward value per unit
     * @dev Callable by operator
     */
    function addRule(
        string calldata _lotteryId,
        uint32 _matchNumber,
        RewardUnit _rewardUnit,
        uint256 _rewardValue
    ) external;

    /**
     * @notice Add more rule reward for lottery payout. Only call when deploying smart contact for the first time
     * @param _lotteryId Lottery id
     * @param _matchNumbers Number match
     * @param _rewardUnits Reward unit
     * @param _rewardValues Reward value per unit
     * @dev Callable by operator
     */
    function addRewardRules(
        string calldata _lotteryId,
        uint32[] calldata _matchNumbers,
        RewardUnit[] calldata _rewardUnits,
        uint256[] calldata _rewardValues
    ) external;

    /**
     *
     * @notice Buy tickets for the current round
     * @param _roundId Rround id
     * @param _tickets array of ticket
     * @dev Callable by users
     */
    function buyTickets(uint256 _roundId, uint32[][] calldata _tickets) external;

    /**
     *
     * @notice Open new round for lottery
     * @param _lotteryId lottery id
     * @param _drawDateTime New session draw datetime (UTC)
     */
    function open(string calldata _lotteryId, uint256 _drawDateTime) external;

    /**
     *
     * @notice Close current round for lottery
     * @param _lotteryId lottery id
     */
    function close(string calldata _lotteryId) external;

    /**
     *
     * @notice Start round by id
     * @param _lotteryId lottery id
     * @dev Callable by operator
     */
    function draw(string calldata _lotteryId) external;
}
