// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IQulotLottery } from "./interfaces/IQulotLottery.sol";
import { IRandomNumberGenerator } from "./interfaces/IRandomNumberGenerator.sol";
import { RoundStatus, RewardUnit } from "./lib/QulotLotteryEnums.sol";
import { String } from "./utils/StringUtils.sol";
import { Lottery, Round, Ticket, Rule } from "./lib/QulotLotteryStructs.sol";

string constant ERROR_CONTRACT_NOT_ALLOWED = "ERROR_CONTRACT_NOT_ALLOWED";
string constant ERROR_PROXY_CONTRACT_NOT_ALLOWED = "ERROR_PROXY_CONTRACT_NOT_ALLOWED";
string constant ERROR_ONLY_OPERATOR = "ERROR_ONLY_OPERATOR";
string constant ERROR_ONLY_TRIGGER_OR_OPERATOR = "ERROR_ONLY_TRIGGER_OR_OPERATOR";
string constant ERROR_ROUND_IS_CLOSED = "ERROR_ROUND_IS_CLOSED";
string constant ERROR_ROUND_NOT_OPEN = "ERROR_ROUND_NOT_OPEN";
string constant ERROR_TICKETS_LIMIT = "ERROR_TICKETS_LIMIT";
string constant ERROR_TICKETS_EMPTY = "ERROR_TICKETS_EMPTY";
string constant ERROR_INVALID_TICKET = "ERROR_INVALID_TICKET";
string constant ERROR_INVALID_ZERO_ADDRESS = "ERROR_INVALID_ZERO_ADDRESS";
string constant ERROR_INVALID_TICKETS_LENGTH_EQUALS_ROUNDS = "ERROR_INVALID_TICKETS_LENGTH_EQUALS_ROUNDS";
string constant ERROR_NOT_TIME_DRAW_LOTTERY = "ERROR_NOT_TIME_DRAW_LOTTERY";
string constant ERROR_NOT_TIME_OPEN_LOTTERY = "ERROR_NOT_TIME_OPEN_LOTTERY";
string constant ERROR_NOT_TIME_CLOSE_LOTTERY = "ERROR_NOT_TIME_CLOSE_LOTTERY";
string constant ERROR_NOT_TIME_REWARD_LOTTERY = "ERROR_NOT_TIME_REWARD_LOTTERY";
string constant ERROR_NOT_TIME_CLAIM_TICKET = "ERROR_NOT_TIME_CLAIM_TICKET";
string constant ERROR_INVALID_WINNING_NUMBERS = "ERROR_INVALID_WINNING_NUMBERS";
string constant ERROR_INVALID_LOTTERY_ID = "ERROR_INVALID_LOTTERY_ID";
string constant ERROR_INVALID_LOTTERY_VERBOSE_NAME = "ERROR_INVALID_LOTTERY_VERBOSE_NAME";
string constant ERROR_INVALID_LOTTERY_PICTURE = "ERROR_INVALID_LOTTERY_PICTURE";
string constant ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS = "ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS";
string constant ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS = "ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS";
string constant ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS = "ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS";
string constant ERROR_INVALID_LOTTERY_PERIOD_DAYS = "ERROR_INVALID_LOTTERY_PERIOD_DAYS";
string constant ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS = "ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS";
string constant ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY = "ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY";
string constant ERROR_INVALID_LOTTERY_PRICE_PER_TICKET = "ERROR_INVALID_LOTTERY_PRICE_PER_TICKET";
string constant ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT = "ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT";
string constant ERROR_INVALID_LOTTERY_DISCOUNT_PERCENT = "ERROR_INVALID_LOTTERY_DISCOUNT_PERCENT";
string constant ERROR_LOTTERY_ALREADY_EXISTS = "ERROR_LOTTERY_ALREADY_EXISTS";
string constant ERROR_INVALID_RULE_REWARD_VALUE = "ERROR_INVALID_RULE_REWARD_VALUE";
string constant ERROR_INVALID_RULE_MATCH_NUMBER = "ERROR_INVALID_RULE_MATCH_NUMBER";
string constant ERROR_INVALID_RULES = "ERROR_INVALID_RULES";
string constant ERROR_INVALID_ROUND_DRAW_TIME = "ERROR_INVALID_ROUND_DRAW_TIME";
string constant ERROR_WRONG_TOKEN_ADDRESS = "ERROR_WRONG_TOKEN_ADDRESS";

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    /* #region Events */
    event TicketsPurchase(address indexed buyer, uint256 indexed roundId, uint256[] ticketIds, uint256 amount);
    event MultiRoundsTicketsPurchase(
        address indexed buyer,
        uint256[] roundIds,
        uint256[] ticketIds,
        uint256[] ticketPrices
    );
    event TicketsClaim(address indexed claimer, uint256 amount, uint256[] ticketIds);
    event NewLottery(string lotteryId, Lottery lottery);
    event NewRewardRule(
        uint ruleIndex,
        string lotteryId,
        uint32 matchNumber,
        RewardUnit rewardUnit,
        uint256 rewardValue
    );
    event RoundOpen(uint256 roundId, string lotteryId, uint256 totalAmount, uint256 startTime, uint256 firstRoundId);
    event RoundClose(uint256 roundId, uint256 totalAmount, uint256 totalTickets);
    event RoundDraw(uint256 roundId, uint32[] numbers);
    event RoundReward(uint256 roundId, uint256 amountTreasury, uint256 amountInjectNextRound, uint256 endTime);
    event RoundInjection(uint256 roundId, uint256 injectedAmount);
    event NewRandomGenerator(address randomGeneratorAddress);
    event AdminTokenRecovery(address token, uint256 amount);
    /* #endregion */

    /* #region States */
    // Mapping lotteryId to lottery info
    string[] private lotteryIds;
    mapping(string => Lottery) private lotteries;

    // Mapping roundId to round info
    uint256[] private roundIds;
    mapping(uint256 => Round) private rounds;
    // Keep track of lottery id for a given lotteryId
    mapping(uint256 => string) private lotteriesPerRoundId;

    // Mapping ticketId to ticket info
    uint256[] private ticketIds;
    mapping(uint256 => Ticket) private tickets;
    // Keep track of user ticket ids for a given roundId
    mapping(address => uint256[]) private ticketsPerUserId;
    mapping(uint256 => uint256[]) private ticketsPerRoundId;

    mapping(string => uint256) public currentRoundIdPerLottery;
    mapping(string => uint256) public amountInjectNextRoundPerLottery;

    mapping(string => Rule[]) public rulesPerLotteryId;

    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    address public treasuryAddress;
    address public triggerAddress;

    IERC20 public immutable token;
    IRandomNumberGenerator public randomGenerator;

    Counters.Counter private counterTicketId;
    Counters.Counter private counterRoundId;
    /* #endregion */

    /* #region Modifiers */
    /* solhint-disable avoid-tx-origin */
    modifier notContract() {
        require(!Address.isContract(msg.sender), ERROR_CONTRACT_NOT_ALLOWED);
        require(msg.sender == tx.origin, ERROR_PROXY_CONTRACT_NOT_ALLOWED);
        _;
    }
    /* solhint-enable */

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, ERROR_ONLY_OPERATOR);
        _;
    }

    modifier onlyOperatorOrTrigger() {
        require(msg.sender == triggerAddress || msg.sender == operatorAddress, ERROR_ONLY_TRIGGER_OR_OPERATOR);
        _;
    }

    /* #endregion */

    /* #region Constructor */
    /**
     *
     * @notice Constructor
     * @param _tokenAddress Address of the ERC20 token
     */
    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    /* #endregion */

    /* #region Methods */

    /**
     *
     * @notice Add new lottery. Only call when deploying smart contact for the first time
     * @param _lotteryId lottery id
     * @param _lottery lottery id
     * @dev Callable by operator
     */
    function addLottery(string memory _lotteryId, Lottery memory _lottery) external override onlyOperator {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(!String.isEmpty(_lottery.picture), ERROR_INVALID_LOTTERY_PICTURE);
        require(!String.isEmpty(_lottery.verboseName), ERROR_INVALID_LOTTERY_VERBOSE_NAME);
        require(_lottery.numberOfItems > 0, ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS);
        require(_lottery.minValuePerItem > 0, ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS);
        require(
            _lottery.maxValuePerItem > 0 && _lottery.maxValuePerItem < type(uint32).max,
            ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS
        );
        require(_lottery.periodDays.length > 0, ERROR_INVALID_LOTTERY_PERIOD_DAYS);
        require(
            _lottery.periodHourOfDays > 0 && _lottery.periodHourOfDays <= 24,
            ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS
        );
        require(
            _lottery.maxNumberTicketsPerBuy > 0 && _lottery.maxNumberTicketsPerBuy < type(uint32).max,
            ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY
        );
        require(_lottery.pricePerTicket > 0, ERROR_INVALID_LOTTERY_PRICE_PER_TICKET);
        require(
            _lottery.treasuryFeePercent >= 0 && _lottery.treasuryFeePercent <= 100,
            ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT
        );
        require(
            _lottery.discountPercent >= 0 && _lottery.discountPercent <= 100,
            ERROR_INVALID_LOTTERY_DISCOUNT_PERCENT
        );

        require(
            !String.compareTwoStrings(lotteries[_lotteryId].verboseName, _lottery.verboseName),
            ERROR_LOTTERY_ALREADY_EXISTS
        );

        lotteries[_lotteryId] = _lottery;
        lotteryIds.push(_lotteryId);

        emit NewLottery(_lotteryId, _lottery);
    }

    /**
     * @notice Add many rules reward for lottery payout. Only call when deploying smart contact for the first time
     * @param _lotteryId Lottery id
     * @param _matchNumbers Number match
     * @param _rewardUnits Reward unit
     * @param _rewardValues Reward value per unit
     * @dev Callable by operator
     */
    function addRewardRules(
        string calldata _lotteryId,
        uint32[] calldata _matchNumbers,
        RewardUnit[] calldata _rewardUnits,
        uint256[] calldata _rewardValues
    ) external override onlyOperator {
        require(
            _matchNumbers.length == _rewardUnits.length && _rewardUnits.length == _rewardValues.length,
            ERROR_INVALID_RULES
        );

        for (uint i = 0; i < _matchNumbers.length; i++) {
            require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
            require(_matchNumbers[i] > 0, ERROR_INVALID_RULE_MATCH_NUMBER);
            require(_rewardValues[i] > 0, ERROR_INVALID_RULE_REWARD_VALUE);

            rulesPerLotteryId[_lotteryId].push(
                Rule({ matchNumber: _matchNumbers[i], rewardUnit: _rewardUnits[i], rewardValue: _rewardValues[i] })
            );
            emit NewRewardRule(i, _lotteryId, _matchNumbers[i], _rewardUnits[i], _rewardValues[i]);
        }
    }

    /**
     *
     * @param _roundId Request id combine lotterylotteryId and lotteryroundId
     * @param _tickets Array of ticket pick numbers
     * @dev Callable by users
     */
    function buyTickets(uint256 _roundId, uint32[][] calldata _tickets) external override notContract nonReentrant {
        // check list tickets is emptyidx
        require(_tickets.length != 0, ERROR_TICKETS_EMPTY);
        // check round is open
        require(rounds[_roundId].status == RoundStatus.Open, ERROR_ROUND_IS_CLOSED);
        // check limit ticket
        require(
            _tickets.length <= lotteries[lotteriesPerRoundId[_roundId]].maxNumberTicketsPerBuy,
            ERROR_TICKETS_LIMIT
        );

        // calculate total price to pay to this contract
        uint256 amountToTransfer = _caculateTotalPriceForBulkTickets(
            lotteries[lotteriesPerRoundId[_roundId]],
            _tickets.length
        );
        // transfer tokens to this contract
        token.safeTransferFrom(address(msg.sender), address(this), amountToTransfer);

        // increment the total amount collected for the round
        rounds[_roundId].totalAmount += amountToTransfer;
        rounds[_roundId].totalTickets += _tickets.length;
        uint256[] memory purchasedTicketIds = new uint256[](_tickets.length);
        for (uint i = 0; i < _tickets.length; i++) {
            uint32[] memory ticketNumbers = _tickets[i];

            // Check valid ticket numbers
            require(_isValidNumbers(ticketNumbers, lotteries[lotteriesPerRoundId[_roundId]]), ERROR_INVALID_TICKET);

            // Increment lottery ticket number
            counterTicketId.increment();
            tickets[counterTicketId.current()] = Ticket({
                owner: msg.sender,
                roundId: _roundId,
                numbers: ticketNumbers,
                winStatus: false,
                winRewardRule: 0,
                winAmount: 0,
                clamStatus: false
            });
            ticketIds.push(counterTicketId.current());
            ticketsPerUserId[msg.sender].push(counterTicketId.current());
            ticketsPerRoundId[_roundId].push(counterTicketId.current());
            purchasedTicketIds[i] = counterTicketId.current();
        }

        emit TicketsPurchase(msg.sender, _roundId, purchasedTicketIds, amountToTransfer);
    }

    /**
     *
     * @notice Buy tickets for the rounds
     * @param _roundIds Rround id
     * @param _tickets array of ticket
     * @dev Callable by users
     */
    function buyTicketsMultiRounds(
        uint256[] calldata _roundIds,
        uint32[][] calldata _tickets
    ) external override notContract nonReentrant {
        // check list tickets is emptyidx
        require(_tickets.length != 0, ERROR_TICKETS_EMPTY);
        require(_tickets.length == _roundIds.length, ERROR_INVALID_TICKETS_LENGTH_EQUALS_ROUNDS);

        // calculate total price to pay to this contract
        uint256 amountToTransfer;

        uint256[] memory purchasedTicketIds = new uint256[](_tickets.length);
        uint256[] memory purchasedTicketPrices = new uint256[](_tickets.length);
        for (uint idx = 0; idx < _roundIds.length; idx++) {
            uint256 roundId = _roundIds[idx];
            // check round is open
            require(rounds[roundId].status == RoundStatus.Open, ERROR_ROUND_IS_CLOSED);
            // check limit ticket
            require(
                _tickets.length <= lotteries[lotteriesPerRoundId[roundId]].maxNumberTicketsPerBuy,
                ERROR_TICKETS_LIMIT
            );

            // amount to transfer need plus for price per ticket
            uint256 ticketPrice = _caculateTotalPriceForBulkTickets(lotteries[lotteriesPerRoundId[roundId]], 1);
            amountToTransfer += ticketPrice;

            uint32[] memory ticketNumbers = _tickets[idx];
            // Check valid ticket numbers
            require(_isValidNumbers(ticketNumbers, lotteries[lotteriesPerRoundId[roundId]]), ERROR_INVALID_TICKET);

            // increment the total amount collected for the round
            rounds[roundId].totalAmount += ticketPrice;
            rounds[roundId].totalTickets += 1;

            // Increment lottery ticket number
            counterTicketId.increment();

            // Set new ticket to mapping tickets
            uint256 newTicketId = counterTicketId.current();
            tickets[newTicketId] = Ticket({
                owner: msg.sender,
                roundId: roundId,
                numbers: ticketNumbers,
                winStatus: false,
                winRewardRule: 0,
                winAmount: 0,
                clamStatus: false
            });
            ticketIds.push(newTicketId);

            // Set new ticket to user
            ticketsPerUserId[msg.sender].push(newTicketId);

            // Set new ticket to round
            ticketsPerRoundId[roundId].push(newTicketId);

            purchasedTicketIds[idx] = newTicketId;
            purchasedTicketPrices[idx] = ticketPrice;
        }

        // transfer tokens to this contract
        token.safeTransferFrom(address(msg.sender), address(this), amountToTransfer);
        emit MultiRoundsTicketsPurchase(msg.sender, _roundIds, purchasedTicketIds, purchasedTicketPrices);
    }

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _ticketIds: array of ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(uint256[] calldata _ticketIds) external override notContract nonReentrant {
        require(_ticketIds.length != 0, ERROR_TICKETS_EMPTY);

        // Initializes the rewardAmountToTransfer
        uint256 rewardAmountToTransfer;
        for (uint i = 0; i < _ticketIds.length; i++) {
            uint256 ticketId = _ticketIds[i];
            require(tickets[ticketId].owner == msg.sender, "ERROR_ONLY_OWNER");
            require(tickets[ticketId].winStatus, "ERROR_TICKET_NOT_WIN");
            require(!tickets[ticketId].clamStatus, "ERROR_ONLY_CLAIM_PRIZE_ONCE");
            tickets[ticketId].clamStatus = true;
            rewardAmountToTransfer += tickets[ticketId].winAmount;
        }

        // Transfer money to msg.sender
        token.safeTransfer(msg.sender, rewardAmountToTransfer);

        emit TicketsClaim(msg.sender, rewardAmountToTransfer, _ticketIds);
    }

    /**
     *
     * @param _lotteryId lottery id
     */
    function open(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(
            (currentRoundId == 0) || (rounds[currentRoundId].status == RoundStatus.Reward),
            ERROR_NOT_TIME_OPEN_LOTTERY
        );

        // Increment current round id of lottery to one
        counterRoundId.increment();
        uint256 nextRoundId = counterRoundId.current();

        // Keep track lottery id and round id
        require(nextRoundId > currentRoundIdPerLottery[_lotteryId], "ERROR_ROUND_ID_LESS_THAN_CURRENT");

        currentRoundIdPerLottery[_lotteryId] = nextRoundId;
        lotteriesPerRoundId[nextRoundId] = _lotteryId;

        // Create new round
        uint256 totalAmount = amountInjectNextRoundPerLottery[_lotteryId];
        rounds[nextRoundId] = Round({
            firstRoundId: currentRoundId,
            winningNumbers: new uint32[](lotteries[_lotteryId].numberOfItems),
            openTime: block.timestamp,
            endTime: 0,
            totalAmount: totalAmount,
            totalTickets: 0,
            status: RoundStatus.Open
        });
        roundIds.push(nextRoundId);

        // Reset amount injection for next round
        amountInjectNextRoundPerLottery[_lotteryId] = 0;

        // Emit round open
        emit RoundOpen(nextRoundId, _lotteryId, totalAmount, block.timestamp, currentRoundId);
    }

    /**
     *
     * @param _lotteryId lottery id
     */
    function close(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(
            (currentRoundId != 0) && rounds[currentRoundId].status == RoundStatus.Open,
            ERROR_NOT_TIME_CLOSE_LOTTERY
        );

        rounds[currentRoundId].status = RoundStatus.Close;

        // Request new random number
        randomGenerator.requestRandomNumbers(
            currentRoundId,
            lotteries[_lotteryId].numberOfItems,
            lotteries[_lotteryId].minValuePerItem,
            lotteries[_lotteryId].maxValuePerItem
        );

        // Emit round close
        emit RoundClose(currentRoundId, rounds[currentRoundId].totalAmount, rounds[currentRoundId].totalTickets);
    }

    /**
     *
     * @notice Start round by id
     * @param _lotteryId round id
     * @dev Callable by operator
     */
    function draw(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(
            (currentRoundId != 0) && rounds[currentRoundId].status == RoundStatus.Close,
            ERROR_NOT_TIME_DRAW_LOTTERY
        );

        // get randomResult generated by ChainLink's fallback
        uint32[] memory winningNumbers = randomGenerator.getRandomResult(currentRoundId);

        // check winning numbers is valid or not
        require(_isValidNumbers(winningNumbers, lotteries[_lotteryId]), ERROR_INVALID_WINNING_NUMBERS);

        rounds[currentRoundId].status = RoundStatus.Draw;
        rounds[currentRoundId].winningNumbers = winningNumbers;

        // Emit round Draw
        emit RoundDraw(currentRoundIdPerLottery[_lotteryId], winningNumbers);
    }

    /**
     *
     * @notice Reward round by id
     * @param _lotteryId round id
     * @dev Callable by operator
     */
    function reward(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(
            (currentRoundId != 0) && rounds[currentRoundId].status == RoundStatus.Draw,
            ERROR_NOT_TIME_REWARD_LOTTERY
        );

        // Set round status to reward
        rounds[currentRoundId].status = RoundStatus.Reward;
        rounds[currentRoundId].endTime = block.timestamp;

        // Estimate
        (uint256 amountTreasury, uint256 amountInject, uint256 rewardAmount) = _estimateReward(
            _lotteryId,
            currentRoundId
        );

        uint256 outRewardValue = _findWinnersAndReward(_lotteryId, currentRoundId, rewardAmount);
        amountInject += outRewardValue;
        amountInjectNextRoundPerLottery[_lotteryId] = amountInject;
        // Transfer token to treasury address
        token.safeTransfer(treasuryAddress, amountTreasury);
        // Emit round Draw
        emit RoundReward(currentRoundId, amountTreasury, amountInject, block.timestamp);
    }

    /**
     * @notice Inject funds
     * @param _roundId: round id
     * @param _amount: amount to inject in token
     * @dev Callable by owner or injector address
     */
    function injectFunds(uint256 _roundId, uint256 _amount) external onlyOwner {
        require(rounds[_roundId].status == RoundStatus.Open, ERROR_ROUND_NOT_OPEN);
        token.safeTransferFrom(address(msg.sender), address(this), _amount);
        rounds[_roundId].totalAmount += _amount;
        emit RoundInjection(_roundId, _amount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(token), ERROR_WRONG_TOKEN_ADDRESS);
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Set the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function setRandomGenerator(address _randomGeneratorAddress) external override onlyOwner {
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
     * @param _triggerAddress The lottery scheduler account used to run regular operations.
     * @dev Callable by owner
     */
    function setTriggerAddress(address _triggerAddress) external onlyOwner {
        require(_triggerAddress != address(0), ERROR_INVALID_ZERO_ADDRESS);
        triggerAddress = _triggerAddress;
    }

    /**
     * @notice Return a list of lottery ids
     */
    function getLotteryIds() external view override returns (string[] memory) {
        return lotteryIds;
    }

    /**
     * @notice Return lottery by id
     * @param _lotteryId Id of lottery
     */
    function getLottery(string calldata _lotteryId) external view override returns (Lottery memory) {
        return lotteries[_lotteryId];
    }

    /**
     * @notice Return a list of round ids
     */
    function getRoundIds() external view override returns (uint256[] memory) {
        return roundIds;
    }

    /**
     * @notice Return round by id
     * @param _roundId Id of round
     */
    function getRound(uint256 _roundId) external view override returns (Round memory) {
        return rounds[_roundId];
    }

    /**
     * @notice Return a length of ticket ids by user address
     */
    function getTicketIdsByUserLength(address _user) external view override returns (uint256) {
        return ticketsPerUserId[_user].length;
    }

    /**
     * @notice Return a list of ticket ids by user address
     * @param _user: user address
     * @param _cursor: cursor to start where to retrieve the tickets
     * @param _size: the number of tickets to retrieve
     * @param _asc: get list order by ascending
     */
    function getTicketIdsByUser(
        address _user,
        uint256 _cursor,
        uint256 _size,
        bool _asc
    ) external view override returns (uint256[] memory ids, uint256 cursor) {
        if (_asc) {
            if (_size > ticketsPerUserId[_user].length - _cursor) {
                _size = ticketsPerUserId[_user].length - _cursor;
            }
        } else {
            if (_size > _cursor) {
                _size = _cursor;
            }
        }
        ids = new uint256[](_size);
        uint256 idx;
        for (uint256 i = 0; i < _size; i++) {
            idx = _asc ? _cursor + i : _cursor - i - 1;
            ids[i] = ticketsPerUserId[_user][idx];
        }
        cursor = _asc ? _cursor + _size : _cursor - _size;
    }

    /**
     * @notice Return ticket by id
     * @param _ticketId Id of round
     */
    function getTicket(uint256 _ticketId) external view override returns (Ticket memory) {
        return tickets[_ticketId];
    }

    /**
     * @notice Find the winners and pay the prizes. the out reward will be added to inject
     * @param _lotteryId Id of lottery
     * @param _roundId Id of round
     * @param rewardAmount Reward amount share for winners
     * @dev Callable by internal
     */
    function _findWinnersAndReward(
        string calldata _lotteryId,
        uint256 _roundId,
        uint256 rewardAmount
    ) internal returns (uint256 outRewardValue) {
        outRewardValue = rewardAmount;
        uint[] memory winnersPerRule = new uint[](rulesPerLotteryId[_lotteryId].length);
        for (uint ticketIndex = 0; ticketIndex < ticketsPerRoundId[_roundId].length; ticketIndex++) {
            uint256 ticketId = ticketsPerRoundId[_roundId][ticketIndex];
            // Check if this ticket is eligible to win or not
            (bool isWin, uint matchRewardRule) = _checkIsWinTicket(ticketId, _lotteryId, _roundId);
            if (isWin) {
                tickets[ticketId].winStatus = isWin;
                tickets[ticketId].winRewardRule = matchRewardRule;
                winnersPerRule[matchRewardRule] += 1;
            }
        }

        uint256[] memory rewardsAmountPerRule = new uint256[](rulesPerLotteryId[_lotteryId].length);
        for (uint ruleIndex = 0; ruleIndex < winnersPerRule.length; ruleIndex++) {
            uint winnerPerRule = winnersPerRule[ruleIndex];
            if (winnerPerRule > 0) {
                uint256 rewardAmountPerRule = _calculateRewardAmountPerRule(_lotteryId, ruleIndex, rewardAmount);
                outRewardValue -= rewardAmountPerRule;
                uint256 rewardAmountPerTicket = rewardAmountPerRule.div(winnerPerRule);
                rewardsAmountPerRule[ruleIndex] = rewardAmountPerTicket;
            }
        }

        for (uint ticketIndex = 0; ticketIndex < ticketsPerRoundId[_roundId].length; ticketIndex++) {
            uint256 ticketId = ticketsPerRoundId[_roundId][ticketIndex];
            if (tickets[ticketId].winStatus) {
                uint256 rewardAmountPerRule = rewardsAmountPerRule[tickets[ticketId].winRewardRule];
                tickets[ticketId].winAmount = rewardAmountPerRule;
            }
        }
    }

    /**
     * @notice Return ticket by id
     * @param _lotteryId Id of lottery
     * @param _roundId Id of round
     * @return treasuryAmount Treasury fee on total prize
     * @return injectAmount Amount inject for the next round
     * @return rewardAmount Number of prizes to be divided among the winners
     */
    function _estimateReward(
        string memory _lotteryId,
        uint256 _roundId
    ) internal view returns (uint256 treasuryAmount, uint256 injectAmount, uint256 rewardAmount) {
        treasuryAmount = _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].treasuryFeePercent);
        injectAmount = _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].amountInjectNextRoundPercent);
        rewardAmount = rounds[_roundId].totalAmount.sub(treasuryAmount).sub(injectAmount);
    }

    /**
     *
     * @notice Check array of numbers is valid or not
     * @param _numbers Array of numbers need check in range LOTTERY require
     * @param _lottery LOTTERYs that users want to check
     */
    function _isValidNumbers(uint32[] memory _numbers, Lottery memory _lottery) internal pure returns (bool) {
        if (_numbers.length != _lottery.numberOfItems) {
            return false;
        }
        for (uint i = 0; i < _numbers.length; i++) {
            uint32 number = _numbers[i];
            if (number < _lottery.minValuePerItem || number > _lottery.maxValuePerItem) {
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
        uint256 totalPrice = _lottery.pricePerTicket * _numberTickets;
        return totalPrice - _percentageOf(totalPrice, _lottery.discountPercent);
    }

    /**
     * @notice Check if the ticket win or not. Returns the index of rule for ticket win
     * @param _ticketId Id of ticket
     * @param _lotteryId Id of lottery
     * @param _roundId Id of round
     * @return isWin Return true if ticket win
     * @return matchRewardRule Rule index rule match
     */
    function _checkIsWinTicket(
        uint256 _ticketId,
        string memory _lotteryId,
        uint256 _roundId
    ) internal view returns (bool isWin, uint matchRewardRule) {
        uint matchedNumbers = _matchNumbersCount(rounds[_roundId].winningNumbers, tickets[_ticketId].numbers);
        if (matchedNumbers != 0) {
            for (uint ruleIndex = 0; ruleIndex < rulesPerLotteryId[_lotteryId].length; ruleIndex++) {
                if (rulesPerLotteryId[_lotteryId][ruleIndex].matchNumber == matchedNumbers) {
                    isWin = true;
                    matchRewardRule = ruleIndex;
                    break;
                }
            }
        }
    }

    /**
     * @notice Calculate the amount to be paid for ticket win rule
     * @param _lotteryId Id of lottery
     * @param _ruleIndex Index of rule
     * @param _rewardAmount Total amount of reward
     */
    function _calculateRewardAmountPerRule(
        string memory _lotteryId,
        uint _ruleIndex,
        uint256 _rewardAmount
    ) internal view returns (uint256) {
        Rule memory rule = rulesPerLotteryId[_lotteryId][_ruleIndex];
        uint256 rewardAmountPerRule;
        if (rule.rewardUnit == RewardUnit.Percent) {
            rewardAmountPerRule = _percentageOf(_rewardAmount, rule.rewardValue);
        } else if (rule.rewardUnit == RewardUnit.Fixed) {
            rewardAmountPerRule = _rewardAmount - rule.rewardValue;
        }
        return rewardAmountPerRule;
    }

    /**
     * @notice Count the matching numbers between 2 arrays
     */
    function _matchNumbersCount(uint32[] memory _arr1, uint32[] memory _arr2) internal pure returns (uint) {
        uint count = 0;
        for (uint arr1Index = 0; arr1Index < _arr1.length; arr1Index++) {
            for (uint arr2Index = 0; arr2Index < _arr2.length; arr2Index++) {
                if (_arr1[arr1Index] == _arr2[arr2Index]) {
                    count++;
                }
            }
        }
        return count;
    }

    /**
     * @notice Calculate the treasury fee
     * @param _lotteryId Id of lottery
     * @param _roundId Id of round
     */
    function _calculateTreasuryFee(string memory _lotteryId, uint256 _roundId) internal view returns (uint256) {
        return _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].treasuryFeePercent);
    }

    /**
     * @notice Calculate percentage value
     */
    function _percentageOf(uint256 amount, uint256 percent) internal pure returns (uint256) {
        require(percent >= 0 && percent <= 100, "INVALID_PERCENT_VALUE");
        return (amount.mul(percent)).div(100);
    }
    /* #endregion */
}
