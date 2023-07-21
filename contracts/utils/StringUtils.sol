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
}
