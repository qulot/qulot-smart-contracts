// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

library Subsets {
    struct Result {
        bytes32 hash;
        uint length;
    }
    struct Subset {
        uint32[] array;
        Result[] results;
        mapping(bytes32 => bool) exists;
    }

    function getListSumOfSubset(Subset storage subset, uint limit) internal {
        uint arrayLength = subset.array.length;
        uint subsetCount = 2 ** arrayLength;

        for (uint256 i; i < subsetCount; ) {
            uint32 length;
            uint32[] memory subsetItem = new uint32[](arrayLength);
            for (uint32 j; j < arrayLength; ) {
                if ((i & (1 << j)) > 0) {
                    subsetItem[j] = subset.array[j];
                    length++;
                }
                unchecked {
                    j++;
                }
            }

            if (length > 0) {
                bytes32 hashSubset = hash(subsetItem);

                if (!subset.exists[hashSubset]) {
                    subset.results.push(Result({ hash: hashSubset, length: length }));
                    subset.exists[hashSubset] = true;
                }
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
