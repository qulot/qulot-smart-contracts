// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Sort } from "./Sort.sol";

library Subsets {
    struct Result {
        bytes32 hash;
        uint length;
    }

    function getHashSubsets(uint32[] memory array, uint limit) internal pure returns (Result[] memory results) {
        uint arrayLength = array.length;
        uint subsetCount = 2 ** arrayLength;
        results = new Result[](subsetCount);

        for (uint i; i < subsetCount; ) {
            uint length;
            uint32[] memory subsetItem = new uint32[](arrayLength);
            for (uint32 j; j < arrayLength; ) {
                if ((i & (1 << j)) > 0) {
                    subsetItem[j] = array[j];
                    length++;
                }
                unchecked {
                    j++;
                }
            }

            if (length > limit) {
                Sort.quickSort(subsetItem, 0, subsetItem.length - 1);
                bytes32 hashSubset = hash(subsetItem);
                results[i] = Result({ hash: hashSubset, length: length });
            }

            unchecked {
                i++;
            }
        }
    }

    function hash(uint32[] memory _array) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_array));
    }
}
