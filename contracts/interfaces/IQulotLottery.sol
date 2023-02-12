// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IQulotLottery {
    /**
     *
     * @param _sessionId Request id combine lotteryProductId and lotterySessionId
     * @param _tickets array of ticket
     * @dev Callable by users
     */
    function buyTickets(
        uint256 _sessionId,
        uint32[][] calldata _tickets
    ) external;

    /**
     *
     * @param _lotteryProductId Lottery product id
     * @dev Callable by operator
     */
    function startDrawProduct(string calldata _lotteryProductId) external;
}
