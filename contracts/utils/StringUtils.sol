// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

library String {
    /**
     * @notice Check string is empty or not
     * @param _str String
     */
    function isEmpty(string memory _str) internal pure returns (bool) {
        return bytes(_str).length == 0;
    }

    /**
     * @notice Compare two strings. Returns true if two strings are equal
     * @param _str1 String 1
     * @param _str2 String 2
     */
    function compareTwoStrings(string memory _str1, string memory _str2) internal pure returns (bool) {
        if (bytes(_str1).length != bytes(_str2).length) {
            return false;
        }
        return keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2));
    }
}
