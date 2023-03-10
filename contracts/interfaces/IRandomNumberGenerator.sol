// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRandomNumberGenerator {
    /**
     *
     * @param _roundId Request id combine lotteryProductId and lotteryroundId
     * @param _numbersOfItems Numbers of items
     * @param _minValuePerItems Min value per items
     * @param _maxValuePerItems Max value per items
     */
    function requestRandomNumbers(
        uint256 _roundId,
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) external;

    /**
     * @param _roundId Request id combine lotteryProductId and lotteryroundId
     */
    function getRandomResult(uint256 _roundId) external view returns (uint32[] memory);

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setLotteryAddress(address _qulotLottery) external;
}
