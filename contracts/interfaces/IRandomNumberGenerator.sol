// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IRandomNumberGenerator {
    /**
     * 
     * @param _variantId Request id combine lotteryProductId and lotterySessionId
     * @param _numbersOfItems Numbers of items
     * @param _minValuePerItems Min value per items
     * @param _maxValuePerItems Max value per items
     */
    function requestRandomNumbers(
        string calldata _variantId,
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) external;

    /**
     * @param _variantId Request id combine lotteryProductId and lotterySessionId
     */
    function getRandomResult(string calldata _variantId) external view returns (uint32[] memory);
}
