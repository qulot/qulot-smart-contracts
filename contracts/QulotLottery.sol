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

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    /* #region Constants */
    string private constant ERROR_CONTRACT_NOT_ALLOWED = "ERROR_CONTRACT_NOT_ALLOWED";
    string private constant ERROR_PROXY_CONTRACT_NOT_ALLOWED = "ERROR_PROXY_CONTRACT_NOT_ALLOWED";
    string private constant ERROR_ONLY_OPERATOR = "ERROR_ONLY_OPERATOR";
    string private constant ERROR_ONLY_TRIGGER_OR_OPERATOR = "ERROR_ONLY_TRIGGER_OR_OPERATOR";
    string private constant ERROR_ROUND_IS_CLOSED = "ERROR_ROUND_IS_CLOSED";
    string private constant ERROR_ROUND_NOT_OPEN = "ERROR_ROUND_NOT_OPEN";
    string private constant ERROR_TICKETS_LIMIT = "ERROR_TICKETS_LIMIT";
    string private constant ERROR_TICKETS_EMPTY = "ERROR_TICKETS_EMPTY";
    string private constant ERROR_INVALID_TICKET = "ERROR_INVALID_TICKET";
    string private constant ERROR_INVALID_ZERO_ADDRESS = "ERROR_INVALID_ZERO_ADDRESS";
    string private constant ERROR_NOT_TIME_DRAW_LOTTERY = "ERROR_NOT_TIME_DRAW_LOTTERY";
    string private constant ERROR_NOT_TIME_OPEN_LOTTERY = "ERROR_NOT_TIME_OPEN_LOTTERY";
    string private constant ERROR_NOT_TIME_CLOSE_LOTTERY = "ERROR_NOT_TIME_CLOSE_LOTTERY";
    string private constant ERROR_NOT_TIME_REWARD_LOTTERY = "ERROR_NOT_TIME_REWARD_LOTTERY";
    string private constant ERROR_INVALID_WINNING_NUMBERS = "ERROR_INVALID_WINNING_NUMBERS";
    string private constant ERROR_INVALID_LOTTERY_ID = "ERROR_INVALID_LOTTERY_ID";
    string private constant ERROR_INVALID_LOTTERY_VERBOSE_NAME = "ERROR_INVALID_LOTTERY_VERBOSE_NAME";
    string private constant ERROR_INVALID_LOTTERY_PICTURE = "ERROR_INVALID_LOTTERY_PICTURE";
    string private constant ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS = "ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS = "ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS = "ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS";
    string private constant ERROR_INVALID_LOTTERY_PERIOD_DAYS = "ERROR_INVALID_LOTTERY_PERIOD_DAYS";
    string private constant ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS = "ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS";
    string private constant ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY =
        "ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY";
    string private constant ERROR_INVALID_LOTTERY_PRICE_PER_TICKET = "ERROR_INVALID_LOTTERY_PRICE_PER_TICKET";
    string private constant ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT = "ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT";
    string private constant ERROR_LOTTERY_ALREADY_EXISTS = "ERROR_LOTTERY_ALREADY_EXISTS";
    string private constant ERROR_INVALID_RULE_REWARD_VALUE = "ERROR_INVALID_RULE_REWARD_VALUE";
    string private constant ERROR_INVALID_RULE_MATCH_NUMBER = "ERROR_INVALID_RULE_MATCH_NUMBER";
    string private constant ERROR_INVALID_RULES = "ERROR_INVALID_RULES";
    string private constant ERROR_INVALID_ROUND_DRAW_TIME = "ERROR_INVALID_ROUND_DRAW_TIME";
    string private constant ERROR_WRONG_TOKEN_ADDRESS = "ERROR_WRONG_TOKEN_ADDRESS";
    /* #endregion */

    /* #region Events */
    event TicketsPurchase(address indexed buyer, uint256 indexed roundId, uint256 numberTickets);
    event TicketsClam(address indexed claimer, uint256 indexed roundId, uint256 amount);
    event NewLottery(string indexed lotteryId, string verboseName);
    event NewRewardRule(string lotteryId, uint32 _matchNumber, RewardUnit rewardUnit, uint256 rewardValue);
    event RoundOpen(uint256 indexed roundId, uint256 startTime);
    event RoundClose(uint256 indexed roundId, uint256 endTime);
    event RoundDraw(uint256 indexed roundId, uint32[] numbers);
    event RoundReward(uint256 indexed roundId, uint256 amountTreasury, uint256 amountInjectNextRound);
    event RoundInjection(uint256 indexed roundId, uint256 injectedAmount);
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
    mapping(uint256 => string) private roundsPerLotteryId;

    // Mapping ticketId to ticket info
    uint256[] private ticketIds;
    mapping(uint256 => Ticket) private tickets;
    // Keep track of user ticket ids for a given roundId
    mapping(address => mapping(uint256 => uint256[])) private userTicketsPerRoundId;
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
     * @param _amountInjectNextRoundPercent Amount inject for next round
     * @dev Callable by operator
     */
    function addLottery(
        string memory _lotteryId,
        string memory _picture,
        string memory _verboseName,
        uint32 _numberOfItems,
        uint32 _minValuePerItem,
        uint32 _maxValuePerItem,
        uint[] memory _periodDays,
        uint _periodHourOfDays,
        uint32 _maxNumberTicketsPerBuy,
        uint256 _pricePerTicket,
        uint32 _treasuryFeePercent,
        uint32 _amountInjectNextRoundPercent
    ) external override onlyOperator {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(!String.isEmpty(_picture), ERROR_INVALID_LOTTERY_PICTURE);
        require(!String.isEmpty(_verboseName), ERROR_INVALID_LOTTERY_VERBOSE_NAME);
        require(_numberOfItems > 0, ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS);
        require(_minValuePerItem > 0, ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS);
        require(_maxValuePerItem > 0 && _maxValuePerItem < type(uint32).max, ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS);
        require(_periodDays.length > 0, ERROR_INVALID_LOTTERY_PERIOD_DAYS);
        require(_periodHourOfDays > 0 && _periodHourOfDays <= 24, ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS);
        require(
            _maxNumberTicketsPerBuy > 0 && _maxNumberTicketsPerBuy < type(uint32).max,
            ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY
        );
        require(_pricePerTicket > 0, ERROR_INVALID_LOTTERY_PRICE_PER_TICKET);
        require(_treasuryFeePercent >= 0, ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT);

        require(
            !String.compareTwoStrings(lotteries[_lotteryId].verboseName, _verboseName),
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
            amountInjectNextRoundPercent: _amountInjectNextRoundPercent,
            totalPrize: 0,
            totalTickets: 0
        });
        lotteryIds.push(_lotteryId);

        emit NewLottery(_lotteryId, _verboseName);
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
            emit NewRewardRule(_lotteryId, _matchNumbers[i], _rewardUnits[i], _rewardValues[i]);
        }
    }

    /**
     *
     * @param _roundId Request id combine lotterylotteryId and lotteryroundId
     * @param _tickets Array of ticket pick numbers
     * @dev Callable by users
     */
    function buyTickets(uint256 _roundId, uint32[][] calldata _tickets) external override notContract nonReentrant {
        // check list tickets is empty
        require(_tickets.length != 0, ERROR_TICKETS_EMPTY);
        // check round is open
        require(rounds[_roundId].status != RoundStatus.Open, ERROR_ROUND_IS_CLOSED);
        // check round too late
        require(block.timestamp < rounds[_roundId].drawDateTime, ERROR_ROUND_IS_CLOSED);
        // check limit ticket
        require(_tickets.length <= lotteries[roundsPerLotteryId[_roundId]].maxNumberTicketsPerBuy, ERROR_TICKETS_LIMIT);

        // calculate total price to pay to this contract
        uint256 amountToTransfer = _caculateTotalPriceForBulkTickets(
            lotteries[roundsPerLotteryId[_roundId]],
            _tickets.length
        );
        // transfer cake tokens to this contract
        token.safeTransferFrom(address(msg.sender), address(this), amountToTransfer);

        // increment the total amount collected for the round
        rounds[_roundId].totalAmount += amountToTransfer;
        lotteries[roundsPerLotteryId[_roundId]].totalPrize += amountToTransfer;
        lotteries[roundsPerLotteryId[_roundId]].totalTickets += _tickets.length;

        for (uint i = 0; i < _tickets.length; i++) {
            uint32[] memory ticketNumbers = _tickets[i];
            require(_isValidNumbers(ticketNumbers, lotteries[roundsPerLotteryId[_roundId]]), ERROR_INVALID_TICKET);
            uint256 newTicketId = counterTicketId.current();
            tickets[newTicketId] = Ticket({
                numbers: ticketNumbers,
                owner: msg.sender,
                winStatus: false,
                winRewardRule: 0,
                winAmount: 0,
                clamStatus: false
            });
            ticketIds.push(newTicketId);
            userTicketsPerRoundId[msg.sender][_roundId].push(newTicketId);
            ticketsPerRoundId[_roundId].push(newTicketId);
            // Increment lottery ticket number
            counterTicketId.increment();
        }

        emit TicketsPurchase(msg.sender, _roundId, _tickets.length);
    }

    /**
     *
     * @param _lotteryId lottery id
     * @param _drawDateTime New round draw datetime (UTC)
     */
    function open(string calldata _lotteryId, uint256 _drawDateTime) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(_drawDateTime > 0, ERROR_INVALID_ROUND_DRAW_TIME);
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status == RoundStatus.Draw),
            ERROR_NOT_TIME_OPEN_LOTTERY
        );

        uint256 firstRoundId = currentRoundIdPerLottery[_lotteryId];
        // Increment current round id of lottery to one
        counterRoundId.increment();
        uint256 nextRoundId = counterRoundId.current();
        currentRoundIdPerLottery[_lotteryId] = nextRoundId;

        // Create new round
        rounds[nextRoundId] = Round({
            firstRoundId: firstRoundId,
            winningNumbers: new uint32[](lotteries[_lotteryId].numberOfItems),
            drawDateTime: _drawDateTime,
            openTime: block.timestamp,
            totalAmount: amountInjectNextRoundPerLottery[_lotteryId],
            status: RoundStatus.Open
        });
        roundIds.push(nextRoundId);

        // Emit round open
        emit RoundOpen(nextRoundId, block.timestamp);

        // Reset amount injection for next round
        amountInjectNextRoundPerLottery[_lotteryId] = 0;
    }

    /**
     *
     * @param _lotteryId lottery id
     */
    function close(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status == RoundStatus.Open),
            ERROR_NOT_TIME_CLOSE_LOTTERY
        );

        rounds[currentRoundIdPerLottery[_lotteryId]].status = RoundStatus.Close;

        // Request new random number
        randomGenerator.requestRandomNumbers(
            currentRoundIdPerLottery[_lotteryId],
            lotteries[_lotteryId].numberOfItems,
            lotteries[_lotteryId].minValuePerItem,
            lotteries[_lotteryId].maxValuePerItem
        );

        // Emit round close
        emit RoundClose(currentRoundIdPerLottery[_lotteryId], block.timestamp);
    }

    /**
     *
     * @notice Start round by id
     * @param _lotteryId round id
     * @dev Callable by operator
     */
    function draw(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(
            (currentRoundId == 0) || (rounds[currentRoundId].status == RoundStatus.Close),
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
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        require(!String.isEmpty(_lotteryId), ERROR_INVALID_LOTTERY_ID);
        require(
            (currentRoundIdPerLottery[_lotteryId] == 0) ||
                (rounds[currentRoundIdPerLottery[_lotteryId]].status == RoundStatus.Draw),
            ERROR_NOT_TIME_REWARD_LOTTERY
        );
        rounds[currentRoundId].status = RoundStatus.Reward;
        uint256 amountTreasury = _percentageOf(
            rounds[currentRoundId].totalAmount,
            uint(lotteries[_lotteryId].treasuryFeePercent)
        );
        uint256 amountInjectNextRound = _percentageOf(
            rounds[currentRoundId].totalAmount,
            uint(lotteries[_lotteryId].amountInjectNextRoundPercent)
        );
        uint256 rewardAmount = rounds[currentRoundId].totalAmount.sub(amountTreasury).sub(amountInjectNextRound);
        uint[] memory winnersPerRule = new uint[](rulesPerLotteryId[_lotteryId].length);
        for (uint ticketIndex = 0; ticketIndex < ticketsPerRoundId[currentRoundId].length; ticketIndex++) {
            uint256 ticketId = ticketsPerRoundId[currentRoundId][ticketIndex];
            // Check if this ticket is eligible to win or not
            (bool isWin, uint matchRewardRule) = _checkIsWinTicket(ticketId, _lotteryId, currentRoundId);
            if (!isWin) {
                continue;
            }
            tickets[ticketId].winStatus = isWin;
            tickets[ticketId].winRewardRule = matchRewardRule;
            winnersPerRule[matchRewardRule] += 1;
        }

        for (uint ruleIndex = 0; ruleIndex < winnersPerRule.length; ruleIndex++) {
            uint winnerPerRule = winnersPerRule[ruleIndex];
            if (winnerPerRule <= 0) {
                continue;
            }

            Rule memory rule = rulesPerLotteryId[_lotteryId][ruleIndex];
            uint rewardAmountPerRule;
            if (rule.rewardUnit == RewardUnit.Percent) {
                rewardAmountPerRule = rewardAmount - _percentageOf(rewardAmount, rule.rewardValue);
            } else if (rule.rewardUnit == RewardUnit.Fixed) {
                rewardAmountPerRule = rewardAmount - rule.rewardValue;
            }

            rewardAmount -= rewardAmountPerRule;
            uint256 rewardAmountPerTicket = rewardAmountPerRule.div(winnerPerRule);
            for (uint ticketIndex = 0; ticketIndex < ticketsPerRoundId[currentRoundId].length; ticketIndex++) {
                uint256 ticketId = ticketsPerRoundId[currentRoundId][ticketIndex];
                if (tickets[ticketId].winStatus && tickets[ticketId].winRewardRule == ruleIndex) {
                    tickets[ticketId].winAmount = rewardAmountPerTicket;
                }
            }
        }

        amountInjectNextRound += rewardAmount;
        amountInjectNextRoundPerLottery[_lotteryId] = amountInjectNextRound;
        // Transfer token to treasury address
        token.safeTransfer(treasuryAddress, amountTreasury);
        // Emit round Draw
        emit RoundReward(currentRoundId, amountTreasury, amountInjectNextRound);
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
     * @notice Change the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function changeRandomGenerator(address _randomGeneratorAddress) external override onlyOwner {
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
     * @notice Return a list of ticket ids
     */
    function getTicketIds() external view override returns (uint256[] memory) {
        return ticketIds;
    }

    /**
     * @notice Return ticket by id
     * @param _ticketId Id of round
     */
    function getTicket(uint256 _ticketId) external view override returns (Ticket memory) {
        return tickets[_ticketId];
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
        return _lottery.pricePerTicket * _numberTickets;
    }

    function _checkIsWinTicket(
        uint256 _ticketId,
        string memory _lotteryId,
        uint256 _roundId
    ) internal view returns (bool isWin, uint matchRewardRule) {
        uint matchedNumbers = _intersectionCount(rounds[_roundId].winningNumbers, tickets[_ticketId].numbers);
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

    function _calculateTreasuryFee(string memory _lotteryId, uint256 _roundId) internal view returns (uint256) {
        return _percentageOf(rounds[_roundId].totalAmount, uint(lotteries[_lotteryId].treasuryFeePercent));
    }

    function _percentageOf(uint256 amount, uint percent) internal pure returns (uint256) {
        return (amount.mul(percent)).div(100);
    }

    function _intersectionCount(uint32[] memory _arr1, uint32[] memory _arr2) internal pure returns (uint) {
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
    /* #endregion */
}
