// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Lottery, RoundView, Rule, TicketView, OrderTicket } from "../lib/QulotLotteryStructs.sol";

interface IQulotLottery {
    /**
     * @notice Set the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     * @dev Callable by operator
     */
    function setRandomGenerator(address _randomGeneratorAddress) external;

    /**
     *
     * @notice Add new lottery. Only call when deploying smart contact for the first time
     * @param _lotteryId lottery id
     * @param _lottery lottery data
     * @dev Callable by operator
     */
    function addLottery(string calldata _lotteryId, Lottery calldata _lottery) external;

    /**
     *
     * @notice Update exists lottery
     * @param _lotteryId lottery id
     * @param _lottery lottery data
     * @dev Callable by operator
     */
    function updateLottery(string calldata _lotteryId, Lottery calldata _lottery) external;

    /**
     * @notice Add more rule reward for lottery payout. Only call when deploying smart contact for the first time
     * @param _lotteryId Lottery id
     * @param _rules Rule list of lottery
     */
    function addRewardRules(string calldata _lotteryId, Rule[] calldata _rules) external;

    /**
     *
     * @notice Buy tickets for the multi rounds
     * @param _buyer Address of buyer
     * @param _ordersTicket Round id
     * @dev Callable by users
     */
    function buyTickets(address _buyer, OrderTicket[] calldata _ordersTicket) external;

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _ticketIds: array of ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(uint256[] calldata _ticketIds) external;

    /**
     *
     * @notice Open new round for lottery
     * @param _lotteryId lottery id
     */
    function open(string calldata _lotteryId) external;

    /**
     *
     * @notice Close current round for lottery
     * @param _lotteryId lottery id
     */
    function close(string calldata _lotteryId) external;

    /**
     *
     * @notice Draw round by id
     * @param _lotteryId lottery id
     * @dev Callable by operator
     */
    function draw(string calldata _lotteryId) external;

    /**
     *
     * @notice Reward round by id
     * @param _lotteryId round id
     * @dev Callable by operator
     */
    function reward(string calldata _lotteryId) external;

    /**
     * @notice Return a list of lottery ids
     */
    function getLotteryIds() external view returns (string[] memory lotteryIds);

    /**
     * @notice Return lottery by id
     * @param _lotteryId Id of lottery
     */
    function getLottery(string calldata _lotteryId) external view returns (Lottery memory lottery);

    /**
     * @notice Return a list of round ids
     */
    function getRoundIds() external view returns (uint256[] memory roundIds);

    /**
     * @notice Return round by id
     * @param _roundId Id of round
     */
    function getRound(uint256 _roundId) external view returns (RoundView memory round);

    /**
     * @notice Return a length of ticket ids
     */
    function getTicketsLength() external view returns (uint256);

    /**
     * @notice Return a length of ticket ids by user address
     */
    function getTicketsByUserLength(address _user) external view returns (uint256);

    /**
     * @notice Return ticket by id
     * @param _ticketId Id of round
     */
    function getTicket(uint256 _ticketId) external view returns (TicketView memory ticket);
}
