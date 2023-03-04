// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IQulotLottery.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./lib/QulotEnums.sol";
import "./lib/QulotStructs.sol";

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
    string private constant ERROR_INVALID_WINNING_NUMBERS =
        "ERROR_INVALID_WINNING_NUMBERS";
    string private constant ERROR_INVALID_LOTTERY_ID =
        "ERROR_INVALID_LOTTERY_ID";
    string private constant ERROR_INVALID_LOTTERY_VERBOSE_NAME =
        "ERROR_INVALID_LOTTERY_VERBOSE_NAME";
    string private constant ERROR_INVALID_LOTTERY_PICTURE =
        "ERROR_INVALID_LOTTERY_PICTURE";
    string private constant ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS =
        "ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS =
        "ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS =
        "ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_PERIOD_DAYS =
        "ERROR_INVALID_LOTTERY_PERIOD_DAYS";
    string private constant ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS =
        "ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS";
    string private constant ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY =
        "ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY";
    string private constant ERROR_INVALID_LOTTERY_PRICE_PER_TICKET =
        "ERROR_INVALID_LOTTERY_PRICE_PER_TICKET";
    string private constant ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT =
        "ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT";
    string private constant ERROR_LOTTERY_ALREADY_EXISTS =
        "ERROR_LOTTERY_ALREADY_EXISTS";
    string private constant ERROR_INVALID_RULE_REWARD_VALUE =
        "ERROR_INVALID_RULE_REWARD_VALUE";
    string private constant ERROR_INVALID_RULE_MATCH_NUMBER =
        "ERROR_INVALID_RULE_MATCH_NUMBER";
    /* #endregion */

    /* #region Events */
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed roundId,
        uint256 numberTickets
    );
    event TicketsClam(
        address indexed claimer,
        uint256 indexed roundId,
        uint256 amount
    );
    event NewLottery(string indexed lotteryId, string verboseName);
    event RoundOpen(uint256 indexed roundId, uint256 startTime);
    event RoundClose(uint256 indexed roundId, uint256 endTime);
    event RoundClaimable(uint256 indexed roundId, uint32[] numbers);
    event NewRandomGenerator(address randomGeneratorAddress);
    /* #endregion */

    /* #region States */
    // Mapping lotteryId to lottery info
    mapping(string => Lottery) public lotteries;

    // Mapping roundId to session info
    mapping(uint256 => Round) public rounds;

    // Mapping ticketId to ticket info
    mapping(uint256 => Ticket) public tickets;

    // Keep track of lottery id for a given lotteryId
    mapping(uint256 => string) public roundsPerLotteryId;

    mapping(string => uint256) public currentRoundIdPerLottery;

    // Keep track of user ticket ids for a given roundId
    mapping(address => mapping(uint256 => uint256[]))
        public userTicketsPerRoundId;

    mapping(string => Rule[]) public rulesPerLotteryId;

    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    address public treasuryAddress;

    IERC20 public token;
    IRandomNumberGenerator public randomGenerator;

    uint256 incrementRoundId;
    uint256 currentTicketId;
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
     * @notice Add new lottery. Only call when deploying smart contact for the first time
     * @param _lotteryId lottery id
     * @param _picture Lottery picture
     * @param _verboseName Verbose name of lottery
     * @param _numberOfItems Numbers on the ticket
     * @param _minValuePerItem Min value per number on the ticket
     * @param _maxValuePerItem Max value per number on the ticket
     * @param _periodDays Daily period of round
     * @param _periodHourOfDays Hourly period of round
     * @param _maxNumberTicketsPerBuy Maximum number of tickets that can be purchased
     * @param _pricePerTicket Price per ticket
     * @param _treasuryFeePercent Treasury fee
     * @dev Callable by operator
     */
    function addLottery(
        string memory _lotteryId,
        string memory _picture,
        string memory _verboseName,
        uint32 _numberOfItems,
        uint32 _minValuePerItem,
        uint32 _maxValuePerItem,
        uint[] calldata _periodDays,
        uint _periodHourOfDays,
        uint32 _maxNumberTicketsPerBuy,
        uint256 _pricePerTicket,
        uint32 _treasuryFeePercent
    ) external override onlyOperator {
        require(bytes(_lotteryId).length > 0, ERROR_INVALID_LOTTERY_ID);
        require(bytes(_picture).length > 0, ERROR_INVALID_LOTTERY_PICTURE);
        require(
            bytes(_verboseName).length > 0,
            ERROR_INVALID_LOTTERY_VERBOSE_NAME
        );
        require(_numberOfItems > 0, ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS);
        require(
            _minValuePerItem > 0,
            ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS
        );
        require(
            _maxValuePerItem > 0 && _maxValuePerItem < type(uint32).max,
            ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS
        );
        require(_periodDays.length > 0, ERROR_INVALID_LOTTERY_PERIOD_DAYS);
        require(
            _periodHourOfDays > 0 && _periodHourOfDays <= 24,
            ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS
        );
        require(
            _maxNumberTicketsPerBuy > 0 &&
                _maxNumberTicketsPerBuy < type(uint32).max,
            ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY
        );
        require(_pricePerTicket > 0, ERROR_INVALID_LOTTERY_PRICE_PER_TICKET);
        require(
            _treasuryFeePercent >= 0,
            ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT
        );

        require(
            !_compareTwoStrings(
                lotteries[_lotteryId].verboseName,
                _verboseName
            ),
            ERROR_LOTTERY_ALREADY_EXISTS
        );

        lotteries[_lotteryId] = Lottery({
            verboseName: _verboseName,
            picture: _picture,
            numberOfItems: _numberOfItems,
            minValuePerItem: _minValuePerItem,
            maxValuePerItem: _maxValuePerItem,
            periodDays: _periodDays,
            periodHourOfDays: _periodHourOfDays,
            maxNumberTicketsPerBuy: _maxNumberTicketsPerBuy,
            pricePerTicket: _pricePerTicket,
            treasuryFeePercent: _treasuryFeePercent,
            totalPrize: 0,
            totalTickets: 0
        });

        emit NewLottery(_lotteryId, _verboseName);
    }

    /**
     * @notice Add more rule reward for lottery payout. Only call when deploying smart contact for the first time
     * @param _lotteryId Lottery id
     * @param matchNumber Number match
     * @param rewardUnit Reward unit
     * @param rewardValue Reward value per unit
     * @dev Callable by operator
     */
    function addRule(
        string calldata _lotteryId,
        uint32 matchNumber,
        RewardUnit rewardUnit,
        uint256 rewardValue
    ) external override onlyOperator {
        require(bytes(_lotteryId).length > 0, ERROR_INVALID_LOTTERY_ID);
        require(matchNumber > 0, ERROR_INVALID_RULE_MATCH_NUMBER);
        require(rewardValue > 0, ERROR_INVALID_RULE_REWARD_VALUE);

        rulesPerLotteryId[_lotteryId].push(
            Rule({
                matchNumber: matchNumber,
                rewardUnit: rewardUnit,
                rewardValue: rewardValue
            })
        );
    }

    /**
     *
     * @param _roundId Request id combine lotterylotteryId and lotteryroundId
     * @param _tickets Array of ticket
     * @dev Callable by users
     */
    function buyTickets(
        uint256 _roundId,
        uint32[][] calldata _tickets
    ) external override notContract nonReentrant {
        // check list tickets is empty
        require(_tickets.length != 0, ERROR_TICKETS_EMPTY);
        // check session is open
        require(
            rounds[_roundId].status != RoundStatus.Open,
            ERROR_SESSION_IS_CLOSED
        );
        // check session too late
        require(
            block.timestamp < rounds[_roundId].drawDateTime,
            ERROR_SESSION_IS_CLOSED
        );
        // check limit ticket
        require(
            _tickets.length <=
                lotteries[roundsPerLotteryId[_roundId]].maxNumberTicketsPerBuy,
            ERROR_TICKETS_LIMIT
        );

        // calculate total price to pay to this contract
        uint256 amountToTransfer = _caculateTotalPriceForBulkTickets(
            lotteries[roundsPerLotteryId[_roundId]],
            _tickets.length
        );
        // transfer cake tokens to this contract
        token.safeTransferFrom(
            address(msg.sender),
            address(this),
            amountToTransfer
        );

        // increment the total amount collected for the round
        rounds[_roundId].totalAmount += amountToTransfer;
        lotteries[roundsPerLotteryId[_roundId]].totalPrize += amountToTransfer;
        lotteries[roundsPerLotteryId[_roundId]].totalTickets += _tickets.length;

        for (uint i = 0; i < _tickets.length; i++) {
            uint32[] memory ticketNumbers = _tickets[i];
            require(
                _isValidNumbers(
                    ticketNumbers,
                    lotteries[roundsPerLotteryId[_roundId]]
                ),
                ERROR_INVALID_TICKET
            );
            tickets[currentTicketId] = Ticket({
                numbers: ticketNumbers,
                owner: msg.sender
            });
            userTicketsPerRoundId[msg.sender][_roundId].push(currentTicketId);
            // Increment lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, _roundId, _tickets.length);
    }

    /**
     *
     * @param _lotteryId lottery id
     * @param _drawDateTime New session draw datetime (UTC)
     */
    function open(
        string calldata _lotteryId,
        uint256 _drawDateTime
    ) external override onlyOperator {
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status ==
                    RoundStatus.Close),
            ERROR_NOT_TIME_ClOSE_LOTTERY
        );

        // Increment current session id of lottery to one
        incrementRoundId++;
        currentRoundIdPerLottery[_lotteryId] = incrementRoundId;

        // Create new session
        rounds[currentRoundIdPerLottery[_lotteryId]] = Round({
            winningNumbers: new uint32[](lotteries[_lotteryId].numberOfItems),
            drawDateTime: _drawDateTime,
            openTime: block.timestamp,
            totalAmount: 0,
            status: RoundStatus.Open
        });

        // Emit session open
        emit RoundOpen(currentRoundIdPerLottery[_lotteryId], block.timestamp);
    }

    /**
     *
     * @param _lotteryId lottery id
     */
    function close(string calldata _lotteryId) external override onlyOperator {
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status ==
                    RoundStatus.Open),
            ERROR_NOT_TIME_ClOSE_LOTTERY
        );

        rounds[currentRoundIdPerLottery[_lotteryId]].status = RoundStatus.Close;

        // Request new random number
        randomGenerator.requestRandomNumbers(
            currentRoundIdPerLottery[_lotteryId],
            lotteries[_lotteryId].numberOfItems,
            lotteries[_lotteryId].minValuePerItem,
            lotteries[_lotteryId].maxValuePerItem
        );

        // Emit session close
        emit RoundClose(currentRoundIdPerLottery[_lotteryId], block.timestamp);
    }

    /**
     *
     * @notice Start round by id
     * @param _lotteryId round id
     * @dev Callable by operator
     */
    function draw(string calldata _lotteryId) external override onlyOperator {
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status ==
                    RoundStatus.Close),
            ERROR_NOT_TIME_DRAW_LOTTERY
        );

        // get randomResult generated by ChainLink's fallback
        uint32[] memory winningNumbers = randomGenerator.getRandomResult(
            currentRoundIdPerLottery[_lotteryId]
        );

        // check winning numbers is valid or not
        require(
            _isValidNumbers(winningNumbers, lotteries[_lotteryId]),
            ERROR_INVALID_WINNING_NUMBERS
        );

        rounds[currentRoundIdPerLottery[_lotteryId]].status = RoundStatus
            .Claimable;
        rounds[currentRoundIdPerLottery[_lotteryId]]
            .winningNumbers = winningNumbers;

        // Emit session claimable
        emit RoundClaimable(
            currentRoundIdPerLottery[_lotteryId],
            winningNumbers
        );
    }

    /**
     * @notice Change the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function changeRandomGenerator(
        address _randomGeneratorAddress
    ) external onlyOwner {
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);
        emit NewRandomGenerator(_randomGeneratorAddress);
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
     *
     * @notice Check array of numbers is valid or not
     * @param _numbers Array of numbers need check in range LOTTERY require
     * @param _lottery LOTTERYs that users want to check
     */
    function _isValidNumbers(
        uint32[] memory _numbers,
        Lottery memory _lottery
    ) internal pure returns (bool) {
        if (_numbers.length != _lottery.numberOfItems) {
            return false;
        }

        for (uint i = 0; i < _numbers.length; i++) {
            uint32 number = _numbers[i];
            if (
                number < _lottery.minValuePerItem ||
                number > _lottery.maxValuePerItem
            ) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Calcuate final price for bulk of tickets
     * @param _lottery LOTTERYs that users want to buy tickets
     * @param _numberTickets Number of tickts want to by
     */
    function _caculateTotalPriceForBulkTickets(
        Lottery memory _lottery,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return _lottery.pricePerTicket * _numberTickets;
    }

    /**
     * @notice Compare two strings. Returns true if two strings are equal
     * @param _str1 String 1
     * @param _str2 String 2
     */
    function _compareTwoStrings(
        string memory _str1,
        string memory _str2
    ) public pure returns (bool) {
        if (bytes(_str1).length != bytes(_str2).length) {
            return false;
        }
        return
            keccak256(abi.encodePacked(_str1)) ==
            keccak256(abi.encodePacked(_str2));
    }

    /* #endregion */
}
