// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ChainlinkClient, Chainlink } from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IRandomNumberGenerator } from "./interfaces/IRandomNumberGenerator.sol";

string constant ERROR_ONLY_QULOT_CONTRACT = "ERROR_ONLY_QULOT_CONTRACT";
string constant ERROR_REQUEST_NOT_FOUND = "ERROR_REQUEST_NOT_FOUND";
string constant ERROR_RESULT_NOT_FOUND = "ERROR_RESULT_NOT_FOUND";

contract QulotLuckyNumberGenerator is ChainlinkClient, IRandomNumberGenerator, Ownable {
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256 roundId;
        uint32 numbersOfItems;
        uint32 minValuePerItems;
        uint32 maxValuePerItems;
        string generator;
        uint32[] results;
    }

    event RequestRandomNumbers(
        uint256 roundId,
        uint32 numbersOfItems,
        uint32 minValuePerItems,
        uint32 maxValuePerItems
    );
    event ResponseRandomNumbers(uint256 roundId, uint32[] results);
    event ChangeApiConfig(string apiEndpoint, string httpMethod);

    // Address of Qulot lottery smart contarct
    address public qulotLotteryAddress;

    mapping(bytes32 => RequestStatus) private requests; /* requestId --> requestStatus */
    mapping(uint256 => bytes32) private requestsByRoundId; /* roundId --> requestId */
    mapping(bytes32 => uint256) private roundsByRequestId; /* requestId --> roundId */

    // The default is 3, but you can set this higher.
    bytes32 private jobId;
    uint256 private fee;
    string private apiEndpoint;
    string private apiHttpMethod;
    string private apiKey;
    address private oracle;
    uint256 private seed;

    /**
     * @notice Constructor
     * @dev ChainLinkRandomNumberGenerator must be deployed before the lottery.
     * Once the lottery contract is deployed, setLotteryAddress must be called.
     * https://docs.chain.link/docs/vrf-contracts/
     */
    constructor(address chainlinkTokenAddress, address chainlinkOracleAddress, uint chainlinkFee) {
        setChainlinkToken(chainlinkTokenAddress);
        oracle = chainlinkOracleAddress;
        fee = ((0 * LINK_DIVISIBILITY) / chainlinkFee); // 0,1 * 10**18 (Varies by network and job)
        apiKey = randomString(20);
    }

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

        Chainlink.Request memory req = _buildChainlinkRequest(_numbersOfItems, _minValuePerItems, _maxValuePerItems);
        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee); // MWR API.
        requests[requestId] = RequestStatus({
            roundId: _roundId,
            numbersOfItems: _numbersOfItems,
            minValuePerItems: _minValuePerItems,
            maxValuePerItems: _maxValuePerItems,
            exists: true,
            fulfilled: false,
            results: new uint32[](_numbersOfItems),
            generator: ""
        });
        requestsByRoundId[_roundId] = requestId;
        roundsByRequestId[requestId] = _roundId;
        emit RequestRandomNumbers(_roundId, _numbersOfItems, _minValuePerItems, _maxValuePerItems);
    }

    function _buildChainlinkRequest(
        uint32 _numbersOfItems,
        uint32 _minValuePerItems,
        uint32 _maxValuePerItems
    ) private view returns (Chainlink.Request memory req) {
        req = buildChainlinkRequest(jobId, address(this), this.fulfillMultipleParameters.selector);
        string memory url = string(
            abi.encodePacked(
                apiEndpoint,
                "?api_key=",
                apiKey,
                "&bulk=",
                Strings.toString(_numbersOfItems),
                "&min=",
                Strings.toString(_minValuePerItems),
                "&max=",
                Strings.toString(_maxValuePerItems)
            )
        );
        req.add(apiHttpMethod, url);
        req.add("path", "data_bytes");
        return req;
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
     * @param _roundId Request id combine lotteryProductId and lotteryroundId
     * @notice View random result
     */
    function getRequestResult(uint256 _roundId) external view returns (RequestStatus memory) {
        require(requests[requestsByRoundId[_roundId]].exists, ERROR_RESULT_NOT_FOUND);
        return requests[requestsByRoundId[_roundId]];
    }

    /**
     * @notice Change the job id
     * @param _jobId How many blocks you'd like the oracle to wait before responding to the request. See SECURITY CONSIDERATIONS for why you may want to request more. The acceptable range is
     */
    function setJobId(bytes32 _jobId) external onlyOwner {
        jobId = _jobId;
    }

    /**
     * @notice Change the job fee
     * @param _fee How many blocks you'd like the oracle to wait before responding to the request. See SECURITY CONSIDERATIONS for why you may want to request more. The acceptable range is
     */
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Set api configuration
     * @param _endpoint Api client https endpoint
     * @param _httpMethod Api http method
     */
    function setApiConfig(string calldata _endpoint, string calldata _httpMethod) external onlyOwner {
        apiEndpoint = _endpoint;
        apiHttpMethod = _httpMethod;
        emit ChangeApiConfig(apiEndpoint, apiHttpMethod);
    }

    /**
     * @notice Set the address for the Qulot
     * @param _qulotLottery: address of the Qulot lottery
     */
    function setQulotLottery(address _qulotLottery) external override onlyOwner {
        qulotLotteryAddress = _qulotLottery;
    }

    /**
     * @notice Set the api key
     * @param _apiKey: address of the Qulot lottery
     * @dev Only callable by owner.
     */
    function setApiKey(string calldata _apiKey) external onlyOwner {
        apiKey = _apiKey;
    }

    /**
     * @notice Return api key generated by smart contract
     * @dev Callable by owner
     */
    function getApiKey() external view onlyOwner returns (string memory) {
        return apiKey;
    }

    /**
     * @notice Fulfillment function for multiple parameters in a single request
     * @dev This is called by the oracle. recordChainlinkFulfillment must be used.
     */
    function fulfillMultipleParameters(
        bytes32 _requestId,
        bytes memory _bytesData
    ) public recordChainlinkFulfillment(_requestId) {
        require(requests[_requestId].exists, ERROR_REQUEST_NOT_FOUND);
        (bool success, string memory generator, uint32[] memory numbers) = abi.decode(
            _bytesData,
            (bool, string, uint32[])
        );
        requests[_requestId].fulfilled = success;
        requests[_requestId].generator = generator;
        requests[_requestId].results = numbers;
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

    function random(uint256 number, uint256 counter) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, counter))) % number;
    }

    /**
     * @notice Picking characters randomly from A-Z, a-z, and 0-9.
     * @param length String length
     */
    function randomString(uint256 length) public view returns (string memory) {
        require(length <= 256, "Length cannot be greater than 256");
        require(length >= 1, "Length cannot be Zero");
        bytes memory randomWord = new bytes(length);
        // since we have 62 Characters
        bytes memory chars = new bytes(62);
        chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        for (uint256 i = 0; i < length; i++) {
            uint256 randomNumber = random(62, i);
            // Index access for string is not possible
            randomWord[i] = chars[randomNumber];
        }
        return string(randomWord);
    }
}
