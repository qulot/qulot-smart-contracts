// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IQulotLottery.sol";
import "./lib/LotteryProduct.sol";
import "./lib/LotterySession.sol";
import "./lib/Enums.sol";

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    string private constant ERROR_CONTRACT_NOT_ALLOWED =
        "ERROR_CONTRACT_NOT_ALLOWED";
    string private constant ERROR_PROXY_CONTRACT_NOT_ALLOWED =
        "ERROR_PROXY_CONTRACT_NOT_ALLOWED";
    string private constant ERROR_ONLY_OPERATOR = "ERROR_ONLY_OPERATOR";
    string private constant ERROR_SESSION_IS_CLOSED = "ERROR_SESSION_IS_CLOSED";
    string private constant ERROR_TICKETS_LIMIT = "ERROR_TICKETS_LIMIT";
    string private constant ERROR_TICKETS_EMPTY = "ERROR_TICKETS_EMPTY";
    string private constant ERROR_INVALID_TICKET = "ERROR_INVALID_TICKET";
    string private constant ERROR_INVALID_ZERO_ADDRESS =
        "ERROR_INVALID_ZERO_ADDRESS";

    mapping(string => LotteryProduct) public products;
    mapping(uint256 => LotterySession) public sessions;
    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    address public treasuryAddress;

    modifier notContract() {
        require(!Address.isContract(msg.sender), ERROR_CONTRACT_NOT_ALLOWED);
        require(msg.sender == tx.origin, ERROR_PROXY_CONTRACT_NOT_ALLOWED);
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, ERROR_ONLY_OPERATOR);
        _;
    }

    /**
     *
     * @param _sessionId Request id combine lotteryProductId and lotterySessionId
     * @param _tickets Array of ticket
     * @dev Callable by users
     */
    function buyTickets(
        uint256 _sessionId,
        uint32[][] calldata _tickets
    ) external override notContract nonReentrant {
        // check list tickets is empty
        require(_tickets.length != 0, ERROR_TICKETS_EMPTY);
        // check session is open
        require(
            sessions[_sessionId].status != SessionStatus.Open,
            ERROR_SESSION_IS_CLOSED
        );
        // check session too late
        require(
            block.timestamp < sessions[_sessionId].drawDateTime,
            ERROR_SESSION_IS_CLOSED
        );
        // check limit ticket
        require(
            _tickets.length <=
                products[sessions[_sessionId].productId].maxNumberTicketsPerBuy,
            ERROR_TICKETS_LIMIT
        );
        LotterySession memory lotterySession = sessions[_sessionId];
        LotteryProduct memory lotteryProduct = products[
            lotterySession.productId
        ];

        for (uint i = 0; i < _tickets.length; i++) {
            require(
                _isValidTicketNumbers(lotteryProduct, _tickets[i]),
                ERROR_INVALID_TICKET
            );

            
        }
    }

    /**
     *
     * @param _lotteryProductId Lottery product id
     * @dev Callable by operator
     */
    function startDrawProduct(
        string calldata _lotteryProductId
    ) external override onlyOperator {}

    /**
     *
     * @param _operatorAddress The lottery scheduler account used to run regular operations.
     * @dev Callable by owner
     */
    function setOperatorAddress(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), ERROR_INVALID_ZERO_ADDRESS);
        operatorAddress = _operatorAddress;
    }

    /**
     *
     * @param _treasuryAddress The address in which the burn is sent
     * @dev Callable by owner
     */
    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), ERROR_INVALID_ZERO_ADDRESS);
        treasuryAddress = _treasuryAddress;
    }

    /**
     * Check ticket numbers is valid or not
     * @param _lotteryProduct Products that users want to buy tickets
     * @param _ticketNumbers User chooses lucky numbers
     */
    function _isValidTicketNumbers(
        LotteryProduct memory _lotteryProduct,
        uint32[] memory _ticketNumbers
    ) internal pure returns (bool) {
        if (_lotteryProduct.numberOfItems != _ticketNumbers.length) {
            return false;
        }
        for (uint i = 0; i < _ticketNumbers.length; i++) {
            uint32 number = _ticketNumbers[i];
            if (
                number <= _lotteryProduct.minValuePerItem ||
                number >= _lotteryProduct.maxValuePerItem
            ) {
                return false;
            }
        }
        return true;
    }
}
