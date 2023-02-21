// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IQulotLottery.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./lib/LotteryProduct.sol";
import "./lib/LotterySession.sol";
import "./lib/LotteryTicket.sol";
import "./lib/Enums.sol";

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    using SafeERC20 for IERC20;

    /* #region Constants */
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
    string private constant ERROR_NOT_TIME_DRAW_LOTTERY =
        "ERROR_NOT_TIME_DRAW_LOTTERY";
    string private constant ERROR_NOT_TIME_OPEN_LOTTERY =
        "ERROR_NOT_TIME_OPEN_LOTTERY";
    string private constant ERROR_NOT_TIME_ClOSE_LOTTERY =
        "ERROR_NOT_TIME_ClOSE_LOTTERY";
    /* #endregion */

    /* #region Events */
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed sessionId,
        uint256 numberTickets
    );
    event TicketsClam(
        address indexed claimer,
        uint256 indexed sessionId,
        uint256 amount
    );
    event SessionOpen(uint256 indexed sessionId, uint256 startTime);
    event SessionClose(uint256 indexed sessionId, uint256 endTime);
    event SessionClaimable(uint256 indexed sessionId, uint32[] numbers);
    /* #endregion */

    /* #region States */
    // Mapping productId to product info
    mapping(string => LotteryProduct) public products;
    // Mapping sessionId to session info
    mapping(uint256 => LotterySession) public sessions;
    // Mapping ticketId to ticket info
    mapping(uint256 => LotteryTicket) public tickets;
    // Keep track of product id for a given productId
    mapping(uint256 => string) public sessionsByProducts;
    mapping(string => uint256) public currentSessionIdByProduct;
    // Keep track of user ticket ids for a given sessionId
    mapping(address => mapping(uint256 => uint256[]))
        public userTicketsPerSessionId;
    uint256 incrementSessionId;
    uint256 public currentTicketId;
    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    address public treasuryAddress;

    IERC20 public token;
    IRandomNumberGenerator public randomGenerator;
    /* #endregion */

    /* #region Modifiers */
    modifier notContract() {
        require(!Address.isContract(msg.sender), ERROR_CONTRACT_NOT_ALLOWED);
        require(msg.sender == tx.origin, ERROR_PROXY_CONTRACT_NOT_ALLOWED);
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, ERROR_ONLY_OPERATOR);
        _;
    }

    /* #endregion */

    /* #region Constructor */
    /**
     *
     * @notice Constructor
     * @param _tokenAddress Address of the ERC20 token
     * @param _randomGeneratorAddress address of the RandomGenerator contract used to work with ChainLink
     */
    constructor(address _tokenAddress, address _randomGeneratorAddress) {
        // init ERC20 contract
        token = IERC20(_tokenAddress);

        // init randomm generators contract
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);
    }

    /* #endregion */

    /* #region Methods */
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
                products[sessionsByProducts[_sessionId]].maxNumberTicketsPerBuy,
            ERROR_TICKETS_LIMIT
        );

        // calculate total price to pay to this contract
        uint256 amountToTransfer = _caculateTotalPriceForBulkTickets(
            products[sessionsByProducts[_sessionId]],
            _tickets.length
        );
        // transfer cake tokens to this contract
        token.safeTransferFrom(
            address(msg.sender),
            address(this),
            amountToTransfer
        );

        // increment the total amount collected for the lottery session
        sessions[_sessionId].totalAmount += amountToTransfer;

        for (uint i = 0; i < _tickets.length; i++) {
            uint32[] memory ticketNumbers = _tickets[i];
            require(
                _isValidTicketNumbers(
                    products[sessionsByProducts[_sessionId]],
                    ticketNumbers
                ),
                ERROR_INVALID_TICKET
            );
            tickets[currentTicketId] = LotteryTicket({
                numbers: ticketNumbers,
                owner: msg.sender
            });
            userTicketsPerSessionId[msg.sender][_sessionId].push(
                currentTicketId
            );
            // Increment lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, _sessionId, _tickets.length);
    }

    /**
     *
     * @param _productId Lottery product id
     * @param _drawDateTime New session draw datetime (UTC)
     */
    function open(
        string calldata _productId,
        uint256 _drawDateTime
    ) internal onlyOwner {
        require(
            (currentSessionIdByProduct[_productId] == 0) ||
                (sessions[currentSessionIdByProduct[_productId]].status ==
                    SessionStatus.Close),
            ERROR_NOT_TIME_ClOSE_LOTTERY
        );

        // Increment current session id of lottery product to one
        incrementSessionId++;
        currentSessionIdByProduct[_productId] = incrementSessionId;

        // Create new session
        sessions[currentSessionIdByProduct[_productId]] = LotterySession({
            winningNumbers: new uint32[](products[_productId].numberOfItems),
            drawDateTime: _drawDateTime,
            openTime: block.timestamp,
            totalAmount: 0,
            status: SessionStatus.Open
        });

        // Emit session open
        emit SessionOpen(
            currentSessionIdByProduct[_productId],
            block.timestamp
        );
    }

    /**
     *
     * @param _productId Lottery product id
     */
    function close(string calldata _productId) internal onlyOwner {
        require(
            (currentSessionIdByProduct[_productId] == 0) ||
                (sessions[currentSessionIdByProduct[_productId]].status ==
                    SessionStatus.Open),
            ERROR_NOT_TIME_ClOSE_LOTTERY
        );

        sessions[currentSessionIdByProduct[_productId]].status = SessionStatus
            .Close;

        // Request new random number
        randomGenerator.requestRandomNumbers(
            currentSessionIdByProduct[_productId],
            products[_productId].numberOfItems,
            products[_productId].minValuePerItem,
            products[_productId].maxValuePerItem
        );

        // Emit session close
        emit SessionClose(
            currentSessionIdByProduct[_productId],
            block.timestamp
        );
    }

    /**
     *
     * @notice Start lottery session by id
     * @param _productId Lottery session id
     * @dev Callable by operator
     */
    function draw(string calldata _productId) external override onlyOperator {
        require(
            (currentSessionIdByProduct[_productId] == 0) ||
                (sessions[currentSessionIdByProduct[_productId]].status ==
                    SessionStatus.Close),
            ERROR_NOT_TIME_DRAW_LOTTERY
        );

        // get randomResult generated by ChainLink's fallback
        uint32[] memory winningNumbers = randomGenerator.getRandomResult(
            currentSessionIdByProduct[_productId]
        );

        sessions[currentSessionIdByProduct[_productId]].status = SessionStatus
            .Claimable;

        // Emit session claimable
        emit SessionClaimable(
            currentSessionIdByProduct[_productId],
            winningNumbers
        );
    }

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

    /**
     * @notice Calcuate final price for bulk of tickets
     * @param _lotteryProduct Products that users want to buy tickets
     * @param _numberTickets Number of tickts want to by
     */
    function _caculateTotalPriceForBulkTickets(
        LotteryProduct memory _lotteryProduct,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return _lotteryProduct.pricePerTicket * _numberTickets;
    }

    /* #endregion */
}
