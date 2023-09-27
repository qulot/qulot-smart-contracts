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
import { RoundStatus } from "./lib/QulotLotteryEnums.sol";
import { String } from "./utils/StringUtils.sol";
import { Subsets } from "./utils/Subsets.sol";
import { Sort } from "./utils/Sort.sol";
import {
    Lottery,
    Round,
    RoundView,
    Ticket,
    Rule,
    OrderTicket,
    OrderTicketResult,
    TicketView
} from "./lib/QulotLotteryStructs.sol";

contract QulotLottery is ReentrancyGuard, IQulotLottery, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    event MultiRoundsTicketsPurchase(address indexed buyer, OrderTicketResult[] ordersResult);
    event TicketsClaim(address indexed claimer, uint256 amount, uint256[] ticketIds);
    event NewLottery(string lotteryId, Lottery lottery);
    event ModifiedLottery(string lotteryId, Lottery lottery);
    event NewRewardRule(uint ruleIndex, string lotteryId, Rule rule);
    event RoundOpen(uint256 roundId, string lotteryId, uint256 totalAmount, uint256 startTime, uint256 firstRoundId);
    event RoundClose(uint256 roundId, uint256 totalAmount, uint256 totalTickets);
    event RoundDraw(uint256 roundId, uint32[] numbers);
    event RoundReward(uint256 roundId, uint256 amountTreasury, uint256 amountInjectNextRound, uint256 endTime);
    event RoundInjection(uint256 roundId, uint256 injectedAmount);
    event NewRandomGenerator(address randomGeneratorAddress);
    event NewAutomationTrigger(address automationTriggerAddress);
    event AdminTokenRecovery(address token, uint256 amount);

    // Mapping lotteryId to lottery info
    string[] public lotteryIds;
    mapping(string => Lottery) public lotteries;

    // Mapping roundId to round info
    uint256[] public roundIds;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(uint => uint256)) public roundRewardsBreakdown;
    mapping(uint256 => mapping(bytes32 => uint32)) private roundTicketsSubsetCounter;

    // Mapping ticketId to ticket info
    uint256[] public ticketIds;
    mapping(uint256 => Ticket) public tickets;

    // Keep track of user ticket ids for a given roundId
    mapping(address => uint256[]) public ticketsPerUserId;
    mapping(uint256 => uint256[]) public ticketsPerRoundId;

    mapping(string => uint256) public currentRoundIdPerLottery;
    mapping(string => uint256) public amountInjectNextRoundPerLottery;

    // Mapping reward rule to lottery id
    mapping(string => mapping(uint => Rule)) public rulesPerLotteryId;
    mapping(string => uint) private limitSubsetPerLottery;

    // Mapping order result to user
    mapping(address => OrderTicketResult[]) public orderResults;

    // The lottery scheduler account used to run regular operations.
    address public operatorAddress;
    address public treasuryAddress;
    address public triggerAddress;

    IERC20 public immutable token;
    IRandomNumberGenerator public randomGenerator;
    uint256 public bulkTicketsDiscountApply = 3;

    Counters.Counter private counterTicketId;
    Counters.Counter private counterRoundId;
    Counters.Counter private counterOrderId;

    /* solhint-disable avoid-tx-origin */
    modifier notContract() {
        require(!Address.isContract(msg.sender), "ERROR_CONTRACT_NOT_ALLOWED");
        require(msg.sender == tx.origin, "ERROR_PROXY_CONTRACT_NOT_ALLOWED");
        _;
    }
    /* solhint-enable */

    modifier onlyOperator() {
        require(_isOperator(), "ERROR_ONLY_OPERATOR");
        _;
    }

    modifier onlyOperatorOrTrigger() {
        require(_isTrigger() || _isOperator(), "ERROR_ONLY_TRIGGER_OR_OPERATOR");
        _;
    }

    function _isTrigger() internal view returns (bool) {
        return msg.sender == triggerAddress;
    }

    function _isOperator() internal view returns (bool) {
        return msg.sender == operatorAddress;
    }

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function addLottery(string calldata _lotteryId, Lottery calldata _lottery) external override onlyOperator {
        _setLottery(_lotteryId, _lottery);
        lotteryIds.push(_lotteryId);
        emit NewLottery(_lotteryId, _lottery);
    }

    function updateLottery(string calldata _lotteryId, Lottery calldata _lottery) external override onlyOperator {
        _setLottery(_lotteryId, _lottery);
        emit ModifiedLottery(_lotteryId, _lottery);
    }

    function addRewardRules(string calldata _lotteryId, Rule[] calldata _rules) external override onlyOperator {
        _addRewardRules(_lotteryId, _rules);
    }

    function buyTickets(
        address _buyer,
        OrderTicket[] calldata _ordersTicket
    ) external override notContract nonReentrant {
        _buyTickets(_buyer, _ordersTicket);
    }

    function claimTickets(uint256[] calldata _ticketIds) external override notContract nonReentrant {
        _claimTickets(_ticketIds);
    }

    function open(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        _open(_lotteryId);
    }

    function close(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        _close(_lotteryId);
    }

    function draw(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        _draw(_lotteryId);
    }

    function reward(string calldata _lotteryId) external override onlyOperatorOrTrigger {
        _reward(_lotteryId);
    }

    function injectFunds(uint256 _roundId, uint256 _amount) external onlyOwner {
        require(rounds[_roundId].isExists && rounds[_roundId].status == RoundStatus.Open, "ERROR_ROUND_NOT_OPEN");
        token.safeTransferFrom(address(msg.sender), address(this), _amount);
        rounds[_roundId].totalAmount += _amount;
        emit RoundInjection(_roundId, _amount);
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(token), "ERROR_WRONG_TOKEN_ADDRESS");
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function setRandomGenerator(address _randomGeneratorAddress) external override onlyOwner {
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);
        emit NewRandomGenerator(_randomGeneratorAddress);
    }

    function setOperatorTreasuryAddress(address _operatorAddress, address _treasuryAddress) external onlyOwner {
        require(_operatorAddress != address(0) && _treasuryAddress != address(0), "ERROR_INVALID_ZERO_ADDRESS");
        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
    }

    function setTriggerAddress(address _triggerAddress) external onlyOwner {
        require(_triggerAddress != address(0), "ERROR_INVALID_ZERO_ADDRESS");
        triggerAddress = _triggerAddress;
        emit NewAutomationTrigger(_triggerAddress);
    }

    function setBulkTicketsDiscountApply(uint256 _numberOfTicket) external onlyOperator {
        bulkTicketsDiscountApply = _numberOfTicket;
    }

    function getLotteryIds() external view override returns (string[] memory) {
        return lotteryIds;
    }

    function getLottery(string calldata _lotteryId) external view override returns (Lottery memory) {
        return lotteries[_lotteryId];
    }

    function getRoundIds() external view override returns (uint256[] memory) {
        return roundIds;
    }

    function getRound(uint256 _roundId) external view override returns (RoundView memory roundResult) {
        Round storage round = rounds[_roundId];
        roundResult = RoundView({
            lotteryId: round.lotteryId,
            winningNumbers: round.winningNumbers,
            endTime: round.endTime,
            openTime: round.openTime,
            totalAmount: round.totalAmount,
            totalTickets: round.totalTickets,
            firstRoundId: round.firstRoundId,
            status: round.status
        });
    }

    function getTicketsLength() external view override returns (uint256) {
        return ticketIds.length;
    }

    function getTicketsByUserLength(address _user) external view override returns (uint256) {
        return ticketsPerUserId[_user].length;
    }

    function getTicket(uint256 _ticketId) external view override returns (TicketView memory ticketResult) {
        (bool isWin, uint winRewardRule, uint256 winAmount) = _checkWinTicket(_ticketId);
        ticketResult = TicketView({
            ticketId: tickets[_ticketId].ticketId,
            numbers: tickets[_ticketId].numbers,
            owner: tickets[_ticketId].owner,
            roundId: tickets[_ticketId].roundId,
            winStatus: isWin,
            winRewardRule: winRewardRule,
            winAmount: winAmount,
            clamStatus: tickets[_ticketId].clamStatus
        });
    }

    function calculateAmountForBulkTickets(
        uint256 _roundId,
        uint256 _numberTickets
    ) external view returns (uint256 totalAmount, uint256 finalAmount, uint256 discount) {
        string storage lotteryId = rounds[_roundId].lotteryId;
        totalAmount = lotteries[lotteryId].pricePerTicket * _numberTickets;
        finalAmount = _calculateTotalPriceForBulkTickets(lotteryId, _numberTickets);
        discount = ((totalAmount.sub(finalAmount)).mul(100)).div(totalAmount);
    }

    function _setLottery(string calldata _lotteryId, Lottery calldata _lottery) internal {
        require(!String.isEmpty(_lotteryId), "ERROR_INVALID_LOTTERY_ID");
        require(!String.isEmpty(_lottery.picture), "ERROR_INVALID_LOTTERY_PICTURE");
        require(!String.isEmpty(_lottery.verboseName), "ERROR_INVALID_LOTTERY_VERBOSE_NAME");
        require(_lottery.numberOfItems > 0 && _lottery.numberOfItems <= 6, "ERROR_INVALID_LOTTERY_NUMBER_OF_ITEMS");
        require(_lottery.minValuePerItem > 0, "ERROR_INVALID_LOTTERY_MIN_VALUE_PER_ITEMS");
        require(
            _lottery.maxValuePerItem > 0 && _lottery.maxValuePerItem < type(uint32).max,
            "ERROR_INVALID_LOTTERY_MAX_VALUE_PER_ITEMS"
        );
        require(_lottery.periodDays.length > 0, "ERROR_INVALID_LOTTERY_PERIOD_DAYS");
        require(
            _lottery.periodHourOfDays > 0 && _lottery.periodHourOfDays <= 24,
            "ERROR_INVALID_LOTTERY_PERIOD_HOUR_OF_DAYS"
        );
        require(
            _lottery.maxNumberTicketsPerBuy > 0 && _lottery.maxNumberTicketsPerBuy < type(uint32).max,
            "ERROR_INVALID_LOTTERY_MAX_NUMBER_TICKETS_PER_BUY"
        );
        require(_lottery.pricePerTicket > 0, "ERROR_INVALID_LOTTERY_PRICE_PER_TICKET");
        require(
            _lottery.treasuryFeePercent >= 0 && _lottery.treasuryFeePercent <= 100,
            "ERROR_INVALID_LOTTERY_TREASURY_FEE_PERCENT"
        );
        require(
            _lottery.discountPercent >= 0 && _lottery.discountPercent <= 100,
            "ERROR_INVALID_LOTTERY_DISCOUNT_PERCENT"
        );

        lotteries[_lotteryId] = _lottery;
    }

    function _addRewardRules(string calldata _lotteryId, Rule[] calldata _rules) internal {
        require(_rules.length > 0, "ERROR_INVALID_RULES");

        uint limitSubset = lotteries[_lotteryId].numberOfItems > 1 ? lotteries[_lotteryId].numberOfItems - 1 : 0;
        for (uint i; i < _rules.length; i++) {
            Rule calldata rule = _rules[i];
            require(rule.matchNumber > 0 && rule.rewardValue > 0, "ERROR_INVALID_RULE");
            rulesPerLotteryId[_lotteryId][rule.matchNumber] = rule;
            if (limitSubset > rule.matchNumber - 1) {
                limitSubset = rule.matchNumber - 1;
            }
            emit NewRewardRule(rule.matchNumber, _lotteryId, rule);
        }

        limitSubsetPerLottery[_lotteryId] = limitSubset;
    }

    function _open(string calldata _lotteryId) internal {
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        if (_isTrigger()) {
            require(
                ((currentRoundId == 0) || (rounds[currentRoundId].status == RoundStatus.Reward)),
                "ERROR_NOT_TIME_OPEN_LOTTERY"
            );
        }
        // Increment current round id of lottery to one
        counterRoundId.increment();
        uint256 nextRoundId = counterRoundId.current();
        // Keep track lottery id and round id
        require(nextRoundId > currentRoundIdPerLottery[_lotteryId], "ERROR_ROUND_ID_LESS_THAN_CURRENT");
        currentRoundIdPerLottery[_lotteryId] = nextRoundId;
        // Create new round
        uint256 totalAmount = amountInjectNextRoundPerLottery[_lotteryId];
        Round storage round = rounds[nextRoundId];
        round.lotteryId = _lotteryId;
        round.firstRoundId = currentRoundId;
        round.winningNumbers = new uint32[](lotteries[_lotteryId].numberOfItems);
        round.openTime = block.timestamp;
        round.totalAmount = totalAmount;
        round.status = RoundStatus.Open;
        round.isExists = true;

        roundIds.push(nextRoundId);
        // Reset amount injection for next round
        amountInjectNextRoundPerLottery[_lotteryId] = 0;
        // Emit round open
        emit RoundOpen(nextRoundId, _lotteryId, totalAmount, block.timestamp, currentRoundId);
    }

    function _close(string calldata _lotteryId) internal {
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        if (_isTrigger()) {
            require(
                (currentRoundId != 0) && rounds[currentRoundId].status == RoundStatus.Open,
                "ERROR_NOT_TIME_CLOSE_LOTTERY"
            );
        }
        rounds[currentRoundId].status = RoundStatus.Close;
        // Request new random number
        Lottery storage lottery = lotteries[_lotteryId];
        randomGenerator.requestRandomNumbers(
            currentRoundId,
            lottery.numberOfItems,
            lottery.minValuePerItem,
            lottery.maxValuePerItem
        );
        // Emit round close
        emit RoundClose(currentRoundId, rounds[currentRoundId].totalAmount, rounds[currentRoundId].totalTickets);
    }

    function _draw(string calldata _lotteryId) internal {
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        if (_isTrigger()) {
            require(
                (currentRoundId != 0) && rounds[currentRoundId].status == RoundStatus.Close,
                "ERROR_NOT_TIME_DRAW_LOTTERY"
            );
        }
        // get randomResult generated by ChainLink's fallback
        uint32[] memory winningNumbers = randomGenerator.getRandomResult(currentRoundId);
        // check winning numbers is valid or not
        require(_isValidNumbers(winningNumbers, _lotteryId), "ERROR_INVALID_WINNING_NUMBERS");
        Sort.quickSort(winningNumbers, 0, winningNumbers.length - 1);
        Round storage round = rounds[currentRoundId];
        round.status = RoundStatus.Draw;
        round.winningNumbers = winningNumbers;
        for (uint i; i < winningNumbers.length; ) {
            round.contains[winningNumbers[i]] = true;
            unchecked {
                i++;
            }
        }
        // Emit round Draw
        emit RoundDraw(currentRoundIdPerLottery[_lotteryId], winningNumbers);
    }

    function _reward(string calldata _lotteryId) internal {
        uint256 currentRoundId = currentRoundIdPerLottery[_lotteryId];
        Round storage round = rounds[currentRoundId];
        if (_isTrigger()) {
            require((currentRoundId != 0) && round.status == RoundStatus.Draw, "ERROR_NOT_TIME_REWARD_LOTTERY");
        }
        // Set round status to reward
        round.status = RoundStatus.Reward;
        round.endTime = block.timestamp;
        // Estimate
        (uint256 amountTreasury, uint256 amountInject, uint256 rewardAmount) = _estimateReward(
            _lotteryId,
            currentRoundId
        );

        uint256 outRewardValue = _calcluateRewardsBreakdown(_lotteryId, currentRoundId, rewardAmount);

        amountInject += outRewardValue;
        amountInjectNextRoundPerLottery[_lotteryId] = amountInject;
        // Transfer token to treasury address
        token.safeTransfer(treasuryAddress, amountTreasury);
        // Emit round Draw
        emit RoundReward(currentRoundId, amountTreasury, amountInject, block.timestamp);
    }

    function _buyTickets(address _buyer, OrderTicket[] calldata _ordersTicket) internal {
        // check list tickets is emptyidx
        require(_ordersTicket.length != 0, "ERROR_TICKETS_EMPTY");
        OrderTicketResult[] memory ordersResult = new OrderTicketResult[](_ordersTicket.length);
        // calculate total price to pay to this contract
        uint256 amountToTransfer;
        OrderTicketResult memory orderTicketResult;
        for (uint orderIdx; orderIdx < _ordersTicket.length; ) {
            orderTicketResult = _processOrder(_buyer, _ordersTicket[orderIdx]);
            amountToTransfer += orderTicketResult.orderAmount;
            ordersResult[orderIdx] = orderTicketResult;
            unchecked {
                orderIdx++;
            }
        }
        // transfer tokens to this contract
        token.safeTransferFrom(address(msg.sender), address(this), amountToTransfer);
        emit MultiRoundsTicketsPurchase(_buyer, ordersResult);
    }

    function _claimTickets(uint256[] calldata _ticketIds) internal {
        require(_ticketIds.length != 0, "ERROR_TICKETS_EMPTY");
        // Initializes the rewardAmountToTransfer
        uint256 rewardAmountToTransfer;
        Ticket storage ticket;
        for (uint i; i < _ticketIds.length; ) {
            // Check ticket valid to claim reward
            ticket = tickets[_ticketIds[i]];
            require(ticket.owner == msg.sender, "ERROR_ONLY_OWNER");

            (bool isWin, , uint256 winAmount) = _checkWinTicket(_ticketIds[i]);
            require(isWin, "ERROR_TICKET_NOT_WIN");
            require(!ticket.clamStatus, "ERROR_ONLY_CLAIM_PRIZE_ONCE");

            // Set claim status to true value
            ticket.clamStatus = true;

            rewardAmountToTransfer += winAmount;
            unchecked {
                i++;
            }
        }
        // Transfer money to msg.sender
        token.safeTransfer(msg.sender, rewardAmountToTransfer);
        emit TicketsClaim(msg.sender, rewardAmountToTransfer, _ticketIds);
    }

    function _calcluateRewardsBreakdown(
        string calldata _lotteryId,
        uint256 _roundId,
        uint256 rewardAmount
    ) internal returns (uint256 outRewardValue) {
        outRewardValue = rewardAmount;

        Round storage round = rounds[_roundId];
        Lottery storage lottery = lotteries[_lotteryId];
        Subsets.Result[] memory subsets = Subsets.getHashSubsets(
            round.winningNumbers,
            limitSubsetPerLottery[_lotteryId]
        );

        uint32[] memory winnersPerRule = new uint32[](lottery.numberOfItems + 1);
        for (uint i; i < subsets.length; ) {
            uint subsetLength = subsets[i].length;
            if (
                roundTicketsSubsetCounter[_roundId][subsets[i].hash] > 0 &&
                rulesPerLotteryId[_lotteryId][subsetLength].rewardValue > 0
            ) {
                winnersPerRule[subsetLength] += roundTicketsSubsetCounter[_roundId][subsets[i].hash];
            }
            unchecked {
                i++;
            }
        }

        uint32 subsetRepeat = winnersPerRule[lottery.numberOfItems] * lottery.numberOfItems;
        for (uint i; i < (winnersPerRule.length - 1); ) {
            if (winnersPerRule[i] >= subsetRepeat) {
                winnersPerRule[i] -= subsetRepeat;
            }
            unchecked {
                i++;
            }
        }

        for (uint ruleIndex; ruleIndex < winnersPerRule.length; ) {
            uint winnerPerRule = winnersPerRule[ruleIndex];
            if (winnerPerRule > 0) {
                uint256 rewardAmountPerRule = _percentageOf(
                    rewardAmount,
                    rulesPerLotteryId[_lotteryId][ruleIndex].rewardValue
                );

                outRewardValue -= rewardAmountPerRule;
                roundRewardsBreakdown[_roundId][ruleIndex] = rewardAmountPerRule.div(winnerPerRule);
            }

            unchecked {
                ruleIndex++;
            }
        }
    }

    function _processOrder(
        address _buyer,
        OrderTicket calldata _order
    ) internal returns (OrderTicketResult memory orderResult) {
        // check list tickets is emptyidx
        require(_order.tickets.length != 0, "ERROR_TICKETS_EMPTY");
        // check round is open
        require(
            rounds[_order.roundId].isExists && rounds[_order.roundId].status == RoundStatus.Open,
            "ERROR_ROUND_IS_CLOSED"
        );
        // check limit ticket
        string storage lotteryId = rounds[_order.roundId].lotteryId;
        require(_order.tickets.length <= lotteries[lotteryId].maxNumberTicketsPerBuy, "ERROR_TICKETS_LIMIT");
        // calculate total price to pay to this contract
        uint256 amountToTransfer = _calculateTotalPriceForBulkTickets(lotteryId, _order.tickets.length);
        // increment the total amount collected for the round
        rounds[_order.roundId].totalAmount += amountToTransfer;
        rounds[_order.roundId].totalTickets += _order.tickets.length;
        uint256[] memory purchasedTicketIds = new uint256[](_order.tickets.length);
        for (uint i; i < _order.tickets.length; ) {
            purchasedTicketIds[i] = _processOrderTicket(_buyer, _order.tickets[i], _order.roundId);
            unchecked {
                i++;
            }
        }
        counterOrderId.increment();
        orderResult = OrderTicketResult({
            orderId: counterOrderId.current(),
            roundId: _order.roundId,
            ticketIds: purchasedTicketIds,
            orderAmount: amountToTransfer,
            timestamp: block.timestamp
        });
        orderResults[_buyer].push(orderResult);
    }

    function _processOrderTicket(
        address _buyer,
        uint32[] calldata _ticketNumbers,
        uint256 _roundId
    ) internal returns (uint256) {
        // Check valid ticket numbers
        require(_isValidNumbers(_ticketNumbers, rounds[_roundId].lotteryId), "ERROR_INVALID_TICKET");

        // Increment lottery ticket number
        counterTicketId.increment();
        uint256 newTicketId = counterTicketId.current();

        // Set new ticket to mapping with storage
        Ticket storage ticket = tickets[newTicketId];
        ticket.ticketId = newTicketId;
        ticket.owner = _buyer;
        ticket.roundId = _roundId;
        ticket.numbers = _ticketNumbers;

        Subsets.Result[] memory ticketSubsets = Subsets.getHashSubsets(
            ticket.numbers,
            limitSubsetPerLottery[rounds[_roundId].lotteryId]
        );
        for (uint i; i < ticketSubsets.length; ) {
            roundTicketsSubsetCounter[ticket.roundId][ticketSubsets[i].hash]++;
            unchecked {
                i++;
            }
        }
        ticketIds.push(newTicketId);
        ticketsPerUserId[_buyer].push(newTicketId);
        ticketsPerRoundId[_roundId].push(newTicketId);
        return newTicketId;
    }

    function _estimateReward(
        string calldata _lotteryId,
        uint256 _roundId
    ) internal view returns (uint256 treasuryAmount, uint256 injectAmount, uint256 rewardAmount) {
        treasuryAmount = _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].treasuryFeePercent);
        injectAmount = _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].amountInjectNextRoundPercent);
        rewardAmount = rounds[_roundId].totalAmount.sub(treasuryAmount).sub(injectAmount);
    }

    function _isValidNumbers(uint32[] memory _numbers, string memory _lotteryId) internal view returns (bool) {
        Lottery storage lottery = lotteries[_lotteryId];
        if (_numbers.length != lottery.numberOfItems) {
            return false;
        }
        uint numberLength = _numbers.length;
        for (uint i; i < numberLength; ) {
            if (_numbers[i] < lottery.minValuePerItem || _numbers[i] > lottery.maxValuePerItem) {
                return false;
            }
            unchecked {
                i++;
            }
        }
        return true;
    }

    function _calculateTotalPriceForBulkTickets(
        string memory _lotteryId,
        uint256 _numberTickets
    ) internal view returns (uint256) {
        uint256 totalPrice = lotteries[_lotteryId].pricePerTicket * _numberTickets;
        if (_numberTickets > bulkTicketsDiscountApply) {
            uint256 totalPriceDiscount = totalPrice - _percentageOf(totalPrice, lotteries[_lotteryId].discountPercent);
            return totalPriceDiscount;
        }
        return totalPrice;
    }

    function _checkWinTicket(
        uint256 _ticketId
    ) internal view returns (bool isWin, uint winRewardRule, uint256 winAmount) {
        Ticket storage ticket = tickets[_ticketId];
        Round storage round = rounds[ticket.roundId];

        // Just check ticket when round status is reward
        if (round.status == RoundStatus.Reward) {
            // Check if this ticket is eligible to win or not
            uint matchedNumbers;
            uint ticketNumbersLength = ticket.numbers.length;
            for (uint i; i < ticketNumbersLength; ) {
                if (round.contains[ticket.numbers[i]]) {
                    matchedNumbers++;
                }
                unchecked {
                    i++;
                }
            }

            if (matchedNumbers > 0) {
                Rule storage rule = rulesPerLotteryId[round.lotteryId][matchedNumbers];
                if (rule.rewardValue > 0) {
                    isWin = true;
                    winRewardRule = matchedNumbers;
                    winAmount = roundRewardsBreakdown[ticket.roundId][winRewardRule];
                }
            }
        }
    }

    function _calculateTreasuryFee(string memory _lotteryId, uint256 _roundId) internal view returns (uint256) {
        return _percentageOf(rounds[_roundId].totalAmount, lotteries[_lotteryId].treasuryFeePercent);
    }

    function _percentageOf(uint256 amount, uint256 percent) internal pure returns (uint256) {
        require(percent >= 0 && percent <= 100, "INVALID_PERCENT_VALUE");
        return (amount.mul(percent)).div(100);
    }
}
