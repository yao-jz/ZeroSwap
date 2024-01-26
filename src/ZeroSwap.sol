// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import "./tokens/ERC20.sol";
// import "./interfaces/IERC20.sol";
// import "./interfaces/IUniswapFactory.sol";
// import "./interfaces/IUniswapExchange.sol";
import {AxiomV2Client} from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";
import { Ownable } from "@openzeppelin-contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
// import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ZeroSwap is AxiomV2Client, Ownable {
    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 public QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 public SOURCE_CHAIN_ID;

    // Hyper Parameters for Q Learning
    uint256 public scalingFactor = 1000000; // 1x scaling factor
    uint256 public windowSize = 10;
    int256 public alpha = 600000; // Learning rate 1x scaling factor
    int256 public gamma = 990000; // discount rate of future rewards 1x scaling factor
    int256 public epsilon = 990000; // probability of exploration vs exploitation - decays over time, this is only the starting epsilon 1x scaling factor
    int256 public mu = 18000000; // 1x scaling factor

    // Q Learning Algorithm
    int256[9][21] public QTable; // 1x scaling factor
    int256[3] public action1;
    int256[3] public action2;
    int256[20] public stateHistory;
    uint256 public pointer;
    int256 public imbalance;
    int256 public midPrice; // 1x scaling factor
    int256 public priceDelta; // 1x scaling factor
    // when buying 1 token1, how many token2 should we pay
    uint256 public askPrice; // 1x scaling factor
    // when selling 1 token1, how many token2 should we receive
    uint256 public bidPrice; // 1x scaling factor
    int256 public lastAction1; // 0, 1, 2
    int256 public lastAction2; // 0, 1, 2

    // Swap Logic
    IERC20 token1;
    IERC20 token2;
    
    // Events
    event Token1AddressUpdated(address indexed token1);
    event Token2AddressUpdated(address indexed token2);
    event AxiomCallbackQuerySchemaUpdated(bytes32 axiomCallbackQuerySchema);
    event Token1Purchase(address indexed buyer, uint256 indexed token2Sold, uint256 indexed token1Bought);
    event Token2Purchase(address indexed buyer, uint256 indexed token1Sold, uint256 indexed token2Bought);
    event AddLiquidity(address indexed provider, uint256 indexed token1Amount, uint256 indexed token2Amount);
    event RemoveLiquidity(address indexed provider, uint256 indexed token1Amount, uint256 indexed token2Amount);

    constructor(
        address _axiomV2QueryAddress,
        uint64 _callbackSourceChainId,
        bytes32 _axiomCallbackQuerySchema
    ) AxiomV2Client(_axiomV2QueryAddress) {
        QUERY_SCHEMA = _axiomCallbackQuerySchema;
        SOURCE_CHAIN_ID = _callbackSourceChainId;
        for (uint256 i = 0; i < 21; i++) {
            for (uint256 j = 0; j < 9; j++) {
                QTable[i][j] = 0;
            }
        }
        action1[0] = -1;
        action1[1] = 0;
        action1[2] = 1;
        action2[0] = -1;
        action2[1] = 0;
        action2[2] = 1;
        for (uint256 i = 0; i < 2*windowSize; i++) {
            stateHistory[i] = 0;
        }
        pointer = 0;
        imbalance = 0;
        midPrice = 1500000;
        priceDelta = 0;
        lastAction1 = 0;
        lastAction2 = 0;
        askPrice = 1100000;
        bidPrice = 900000;
    }

    function _axiomV2Callback(
        uint64, /* sourceChainId */
        address, /* callerAddr */
        bytes32, /* querySchema */
        uint256, /* queryId */
        bytes32[] calldata axiomResults,
        bytes calldata /* extraData */
    ) internal virtual override {

        // Parse results
        lastAction1 = int256(uint256(axiomResults[0]));
        lastAction2 = int256(uint256(axiomResults[1]));
        uint32 _indexN = uint32(uint256(axiomResults[2]));
        uint32 _indexA = uint32(uint256(axiomResults[3]));
        int256 _updatedQValue = int256(uint256(axiomResults[4]));
        int256 _swapValue = int256(uint256(axiomResults[5]));
        int256 _midPrice = int256(uint256(axiomResults[6]));
        int256 _priceDelta = int256(uint256(axiomResults[7]));
        uint256 _askPrice = uint256(axiomResults[8]);
        uint256 _bidPrice = uint256(axiomResults[9]);
        int256 _imbalance = int256(uint256(axiomResults[10]));

        address _userAddr = address(uint160(uint256(axiomResults[11])));
        uint256 _direction = uint256(axiomResults[12]);

        int256 txValue = 0;

        // Swap logic
        if (_direction == 0) {
            txValue = swapToken1ForToken2(_userAddr, uint256(_swapValue));
        } else if (_direction == 1) {
            txValue = swapToken2ForToken1(_userAddr, uint256(_swapValue));
        }

        QTable[_indexN][_indexA] = _updatedQValue;
        stateHistory[pointer] = txValue;
        pointer = (pointer + 1) % (2*windowSize);
        midPrice = _midPrice;
        priceDelta = _priceDelta;
        askPrice = _askPrice;
        bidPrice = _bidPrice;
        imbalance = _imbalance;
        epsilon = epsilon - 1000;
    }

    function _validateAxiomV2Call(
        AxiomCallbackType, // callbackType,
        uint64 sourceChainId,
        address, // caller,
        bytes32 querySchema,
        uint256, // queryId,
        bytes calldata // extraData
    ) internal view override {
        require(sourceChainId == SOURCE_CHAIN_ID, "Source chain ID does not match");
        require(querySchema == QUERY_SCHEMA, "Invalid query schema");
    }

    function updateToken1(address _token) public onlyOwner {
        token1 = IERC20(_token);
        emit Token1AddressUpdated(_token);
    }

    function updateToken2(address _token) public onlyOwner {
        token2 = IERC20(_token);
        emit Token2AddressUpdated(_token);
    }

    function updateCallbackQuerySchema(bytes32 _axiomCallbackQuerySchema) public onlyOwner {
        QUERY_SCHEMA = _axiomCallbackQuerySchema;
        emit AxiomCallbackQuerySchemaUpdated(_axiomCallbackQuerySchema);
    }

    function token1Address() public view returns (address) {
        return address(token1);
    }
    function token2Address() public view returns (address) {
        return address(token2);
    }

    function getPointer() public view returns (uint256) {
        return pointer;
    }

    function getImbalance() public view returns (int256) {
        return imbalance;
    }

    function getMidPrice() public view returns (int256) {
        return midPrice;
    }

    function getPriceDelta() public view returns (int256) {
        return priceDelta;
    }

    function setMidPrice(int256 _midPrice) public onlyOwner {
        midPrice = _midPrice;
    }

    function setPriceDelta(int256 _priceDelta) public onlyOwner {
        priceDelta = _priceDelta;
    }

    function setAskPrice(uint256 _askPrice) public onlyOwner {
        askPrice = _askPrice;
    }

    function setBidPrice(uint256 _bidPrice) public onlyOwner {
        bidPrice = _bidPrice;
    }

    function setAlpha(int256 _alpha) public onlyOwner {
        alpha = _alpha;
    }

    function setGamma(int256 _gamma) public onlyOwner {
        gamma = _gamma;
    }

    function setEpsilon(int256 _epsilon) public onlyOwner {
        epsilon = _epsilon;
    }

    function setMu(int256 _mu) public onlyOwner {
        mu = _mu;
    }

    function getAskPrice() public view returns (uint256) {
        return askPrice;
    }

    function getBidPrice() public view returns (uint256) {
        return bidPrice;
    }

    function getLastAction1() public view returns (int256) {
        return lastAction1;
    }

    function getLastAction2() public view returns (int256) {
        return lastAction2;
    }

    function getQTable() public view returns (int256[9][21] memory) {
        return QTable;
    }

    function getStateHistory() public view returns (int256[20] memory) {
        return stateHistory;
    }

    function getQTableValue(uint256 _indexN, uint256 _indexA) public view returns (int256) {
        return QTable[_indexN][_indexA];
    }

    function getStateHistoryValue(uint256 _index) public view returns (int256) {
        return stateHistory[_index];
    }

    function addLiquidity(uint256 _token1Amount, uint256 _token2Amount) public onlyOwner {
        require(_token1Amount > 0, "Token1 amount must be greater than 0");
        require(_token2Amount > 0, "Token2 amount must be greater than 0");
        token1.transferFrom(msg.sender, address(this), _token1Amount);
        token2.transferFrom(msg.sender, address(this), _token2Amount);
        emit AddLiquidity(msg.sender, _token1Amount, _token2Amount);
    }

    function removeLiquidity(uint256 _token1Amount, uint256 _token2Amount) public onlyOwner {
        require(_token1Amount > 0, "Token1 amount must be greater than 0");
        require(_token2Amount > 0, "Token2 amount must be greater than 0");
        token1.transfer(msg.sender, _token1Amount);
        token2.transfer(msg.sender, _token2Amount);
        emit RemoveLiquidity(msg.sender, _token1Amount, _token2Amount);
    }

    //  buy (𝑑𝑡 = +1), sell (𝑑𝑡 = −1) 
    function swapToken1ForToken2(address user, uint256 _token1Amount) public returns (int256){
        require(_token1Amount > 0, "Token1 amount must be greater than 0");
        token1.transferFrom(user, address(this), _token1Amount);
        uint256 _token2Amount = uint256(_token1Amount * bidPrice / scalingFactor);
        token2.transfer(user, uint256(_token2Amount));
        emit Token2Purchase(user, _token1Amount, _token2Amount);
        return -1 * int256(_token1Amount);
    }

    function swapToken2ForToken1(address user, uint256 _token2Amount) public returns (int256){
        require(_token2Amount > 0, "Token2 amount must be greater than 0");
        token2.transferFrom(user, address(this), _token2Amount);
        uint256 _token1Amount = uint256(_token2Amount * scalingFactor / askPrice);
        token1.transfer(user, uint256(_token1Amount));
        emit Token1Purchase(user, _token2Amount, _token1Amount);
        return int256(_token1Amount);
    }
}