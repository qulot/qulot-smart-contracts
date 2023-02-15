// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IQulotLottery {
    /**
     *
     * @notice Buy tickets for the current lottery session
     * @param _sessionId RLottery session id
     * @param _tickets array of ticket
     * @dev Callable by users
     */
    function buyTickets(
        uint256 _sessionId,
        uint32[][] calldata _tickets
    ) external;

    /**
     *
     * @notice Start lottery session by id
     * @param _sessionId Lottery session id
     * @dev Callable by operator
     */
    function startSession(uint256 _sessionId) external;

    /**
     *
     * @notice Close lottery session by id
     * @param _sessionId Lottery session id
     * @dev Callable by operator
     */
    function closeSession(uint256 _sessionId) external;
}
