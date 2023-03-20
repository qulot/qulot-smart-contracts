// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { IRandomNumberGenerator } from "./interfaces/IRandomNumberGenerator.sol";

contract ChainLinkRandomNumberGenerator is VRFConsumerBaseV2, IRandomNumberGenerator, Ownable {
    using SafeERC20 for IERC20;
    /* #region Constants */
    /* #endregion */

    /* #region Structs */
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256 roundId;
        uint32 numbersOfItems;
        uint32 minValuePerItems;
        uint32 maxValuePerItems;
        uint32[] results;
    }
    /* #endregion */

    /* #region Constants */
    string private constant ERROR_ONLY_QULOT_CONTRACT = "ERROR_ONLY_QULOT_CONTRACT";
    string private constant ERROR_INVALID_KEY_HASH = "ERROR_INVALID_KEY_HASH";
    string private constant ERROR_REQUEST_NOT_FOUND = "ERROR_REQUEST_NOT_FOUND";
    string private constant ERROR_RESULT_NOT_FOUND = "ERROR_RESULT_NOT_FOUND";
    /* #endregion */

    /* #region Events */
    event RequestRandomNumbers(
        uint256 roundId,
        uint32 numbersOfItems,
        uint32 minValuePerItems,
        uint32 maxValuePerItems
    );
    event ResponseRandomNumbers(uint256 roundId, uint32[] results);
    /* #endregion */

    /* #region States */
    // Address of Qulot lottery smart contarct
    address public qulotLotteryAddress;

    // Corresponds to a particular oracle job which uses
    // that key for generating the VRF proof. Different keyHash's have different gas price
    // eilings, so you can select a specific one to bound your maximum per request cost.
    bytes32 private keyHash;

    mapping(uint256 => RequestStatus) private requests; /* requestId --> requestStatus */
    mapping(uint256 => uint256) private requestsByRoundId; /* roundId --> requestId */
    mapping(uint256 => uint256) private roundsByRequestId; /* requestId --> roundId */

    VRFCoordinatorV2Interface COORDINATOR;
    // ChainLink VRF subscription id
    uint64 private subscriptionId;

    // The default is 3, but you can set this higher.
    uint16 private requestConfirmations = 3;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 private callbackGasLimit = 100000;

    /* #endregion */

    /* #region Constructor */
    /**
     * @notice Constructor
     * @dev ChainLinkRandomNumberGenerator must be deployed before the lottery.
     * Once the lottery contract is deployed, setLotteryAddress must be called.
     * https://docs.chain.link/docs/vrf-contracts/
     * @param _vrfCoordinator: address of the VRF coordinator
     */
    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    /* #endregion */

    /* #region Methods */
    /**
     * @param _roundId Request id combine lotteryProductId and lotteryroundId
     * @param _numbersOfItems Number of items
     * @param _minValuePerItems Min value per items
     * @param _maxValuePerItems Max value per items
     */
    function requestRandomNumbers(
        uint256 _roundId,
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) external override {
        require(msg.sender == qulotLotteryAddress, ERROR_ONLY_QULOT_CONTRACT);
        require(keyHash != bytes32(0), ERROR_INVALID_KEY_HASH);

        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            _numbersOfItems
        );
        requests[requestId] = RequestStatus({
            roundId: _roundId,
            numbersOfItems: _numbersOfItems,
            minValuePerItems: _minValuePerItems,
            maxValuePerItems: _maxValuePerItems,
            exists: true,
            fulfilled: false,
            results: new uint32[](_numbersOfItems)
        });
        requestsByRoundId[_roundId] = requestId;
        roundsByRequestId[requestId] = _roundId;
        emit RequestRandomNumbers(_roundId, _numbersOfItems, _minValuePerItems, _maxValuePerItems);
    }

    /**
     * @param _roundId Request id combine lotteryProductId and lotteryroundId
     * @notice View random result
     */
    function getRandomResult(uint256 _roundId) external view override returns (uint32[] memory) {
        require(requests[requestsByRoundId[_roundId]].exists, ERROR_RESULT_NOT_FOUND);
        return requests[requestsByRoundId[_roundId]].results;
    }

    /**
     * @notice Change the callbackGasLimit
     * @param _callbackGasLimit callback
     */
    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    /**
     * @notice Change the keyHash
     * @param _keyHash: new keyHash
     */
    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    /**
     * @notice Change the requestConfirmations
     * @param _requestConfirmations How many blocks you'd like the oracle to wait before responding to the request. See SECURITY CONSIDERATIONS for why you may want to request more. The acceptable range is
     */
    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setQulotLottery(address _qulotLottery) external override onlyOwner {
        qulotLotteryAddress = _qulotLottery;
    }

    /**
     * @notice Callback function used by ChainLink's VRF Coordinator
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(requests[_requestId].exists, ERROR_REQUEST_NOT_FOUND);

        for (uint i = 0; i < _randomWords.length; i++) {
            // transform the result to a number between min and max inclusively
            uint32 resultInRange = uint32(
                (_randomWords[i] % requests[_requestId].maxValuePerItems) + requests[_requestId].minValuePerItems
            );
            requests[_requestId].results[i] = resultInRange;
        }

        requests[_requestId].fulfilled = true;
        emit ResponseRandomNumbers(roundsByRequestId[_requestId], requests[_requestId].results);
    }

    /**
     * @notice It allows the admin to withdraw tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function withdrawTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    /**
     * @notice Set subcription id for chainlink VRF
     * @param _subscriptionId ChainLink VRF subscription id
     * @dev Only callable by owner.
     */
    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }
    /* #endregion */
}
