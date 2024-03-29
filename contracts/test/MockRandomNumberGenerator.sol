//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IRandomNumberGenerator } from "../interfaces/IRandomNumberGenerator.sol";
import { IQulotLottery } from "../interfaces/IQulotLottery.sol";

contract MockRandomNumberGenerator is IRandomNumberGenerator, Ownable {
    address public qulotLottery;
    mapping(uint256 => uint32[]) public results;

    // Initializing the state variable
    uint private _randNonce = 0;

    function requestRandomNumbers(
        uint256 _roundId,
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

        results[_roundId] = winningNumbers;
    }

    function getRandomResult(uint256 _roundId) external view override returns (uint32[] memory) {
        return results[_roundId];
    }

    function setRandomResult(uint256 _roundId, uint32[] memory _winningNumbers) external {
        results[_roundId] = _winningNumbers;
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setQulotLottery(address _qulotLottery) external override {
        qulotLottery = _qulotLottery;
    }
}
