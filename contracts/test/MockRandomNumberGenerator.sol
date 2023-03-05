//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IRandomNumberGenerator } from "../interfaces/IRandomNumberGenerator.sol";
import { IQulotLottery } from "../interfaces/IQulotLottery.sol";

contract MockRandomNumberGenerator is IRandomNumberGenerator, Ownable {
    address public qulotLottery;
    mapping(uint256 => uint32[]) public results;

    // Initializing the state variable
    uint private _randNonce = 0;

    function requestRandomNumbers(
        uint256 _sessionId,
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) external override {
        require(msg.sender == qulotLottery, "Only QulotLottery");
        uint32[] memory winningNumbers = new uint32[](_numbersOfItems);
        for (uint i = 0; i < _numbersOfItems; i++) {
            // increase nonce
            _randNonce++;
            uint randomHash = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, _randNonce)));
            uint32 resultInRange = uint32((randomHash % _maxValuePerItems) + _minValuePerItems);
            winningNumbers[i] = resultInRange;
        }

        results[_sessionId] = winningNumbers;
    }

    function getRandomResult(uint256 _sessionId) external view override returns (uint32[] memory) {
        return results[_sessionId];
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setLotteryAddress(address _qulotLottery) external override {
        qulotLottery = _qulotLottery;
    }
}
