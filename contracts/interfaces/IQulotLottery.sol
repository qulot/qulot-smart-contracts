// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IQulotLottery {
    /**
     *
     * @param _variantId Request id combine lotteryProductId and lotterySessionId
     * @param _ticketNumbers array of ticket numbers
     * @dev Callable by users
     */
    function buyTickets(
        string calldata _variantId,
        uint32[] calldata _ticketNumbers
    ) external;


    /**
     * 
     * @param _lotteryProductId Lottery product id
     * @dev Callable by operator
     */
    function startDrawProduct(string calldata _lotteryProductId) external;
}
