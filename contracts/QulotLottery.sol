// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IQulotLottery.sol";

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    enum SessionStatus {
        Waiting,
        Drawing,
        Rewarding,
        Completed
    }

    struct LotteryProduct {
        string productId;
        string verboseName;
        string picture;
        uint32 numberOfItems;
        uint32 minValuePerItem;
        uint32 maxValuePerItem;
        uint[] periodDays;
        uint periodHourOfDays;
        uint256 usdPricePerTicket;
        uint maxNumberTicketsPerBuy;
    }

    struct LotterySession {
        uint256 sessionId;
        string productId;
        uint32[] winningNumbers;
        uint256 drawDateTime;
        uint256 amount;
        SessionStatus status;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    mapping (string => LotteryProduct) public products;
    mapping (uint256 => LotterySession) public sessions;

    /**
     *
     * @param _sessionId Request id combine lotteryProductId and lotterySessionId
     * @param _tickets array of ticket
     * @dev Callable by users
     */
    function buyTickets(
        uint256 _sessionId,
        uint32[][] calldata _tickets
    ) external override notContract nonReentrant {
        require(_tickets.length != 0, "No ticket specified");
        require(sessions[_sessionId].status != SessionStatus.Waiting, "Session is closed");
        require(block.timestamp < sessions[_sessionId].drawDateTime, "Session is closed");
        require(_tickets.length <= products[sessions[_sessionId].productId].maxNumberTicketsPerBuy, "Too many tickets");

        
    }

    /**
     *
     * @param _lotteryProductId Lottery product id
     * @dev Callable by operator
     */
    function startDrawProduct(
        string calldata _lotteryProductId
    ) external override {}

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
