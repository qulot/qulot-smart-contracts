// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./interfaces/IQulotLottery.sol";

contract ChainLinkRandomNumberGenerator is
    VRFConsumerBaseV2,
    IRandomNumberGenerator,
    Ownable
{
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        string variantId;
        uint32 numbersOfItems;
        uint32 minValuePerItems;
        uint32 maxValuePerItems;
        uint32[] results;
    }

    address private qulotLotteryAddress;

    // Corresponds to a particular oracle job which uses
    // that key for generating the VRF proof. Different keyHash's have different gas price
    // eilings, so you can select a specific one to bound your maximum per request cost.
    bytes32 private keyHash;
    // past requests Id.
    uint256[] private requestIds;
    // lastest request id
    uint256 private latestRequestId;

    mapping(uint256 => RequestStatus)
        private requests; /* requestId --> requestStatus */
    mapping(string => RequestStatus)
        private requestsByVariantId; /* variantId --> requestStatus */

    VRFCoordinatorV2Interface COORDINATOR;
    // ChainLink VRF subscription id
    uint64 private subscriptionId;

    // The default is 3, but you can set this higher.
    uint16 private requestConfirmations;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 private callbackGasLimit = 100000;

    /**
     * @notice Constructor
     * @dev ChainLinkRandomNumberGenerator must be deployed before the lottery.
     * Once the lottery contract is deployed, setLotteryAddress must be called.
     * https://docs.chain.link/docs/vrf-contracts/
     * @param _vrfCoordinator: address of the VRF coordinator
     * @param _subscriptionId: ChainLink VRF subscription id
     */
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
    }

    /**
     * @param _variantId Request id combine lotteryProductId and lotterySessionId
     * @param _numbersOfItems Number of items
     * @param _minValuePerItems Min value per items
     * @param _maxValuePerItems Max value per items
     */
    function requestRandomNumbers(
        string calldata _variantId,
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) external override {
        require(
            msg.sender == qulotLotteryAddress,
            "Only Qulot Lottery Address"
        );
        require(keyHash != bytes32(0), "Must have valid key hash");
        // require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK tokens");

        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            _numbersOfItems
        );
        requests[requestId] = RequestStatus({
            variantId: _variantId,
            numbersOfItems: _numbersOfItems,
            minValuePerItems: _minValuePerItems,
            maxValuePerItems: _maxValuePerItems,
            exists: true,
            fulfilled: false,
            results: new uint32[](_numbersOfItems)
        });
        requestsByVariantId[_variantId] = requests[requestId];
        requestIds.push(requestId);
        latestRequestId = requestId;
    }

    /**
     * @param _variantId Request id combine lotteryProductId and lotterySessionId
     * @notice View random result
     */
    function getRandomResult(
        string calldata _variantId
    ) external view override returns (uint32[] memory) {
        require(requestsByVariantId[_variantId].exists, "Result not found");
        return requestsByVariantId[_variantId].results;
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
    function setRequestConfirmations(
        uint16 _requestConfirmations
    ) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setLotteryAddress(address _qulotLottery) external onlyOwner {
        qulotLotteryAddress = _qulotLottery;
    }

    /**
     * @notice Callback function used by ChainLink's VRF Coordinator
     */
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(requests[_requestId].exists, "request not found");

        for (uint i = 0; i < _randomWords.length; i++) {
            // transform the result to a number between min and max inclusively
            uint32 resultInRange = uint32(
                (_randomWords[i] % requests[_requestId].maxValuePerItems) +
                    requests[_requestId].minValuePerItems
            );
            requests[_requestId].results[i] = resultInRange;
        }

        requests[_requestId].fulfilled = true;
    }
}