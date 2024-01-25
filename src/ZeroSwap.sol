// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import "./tokens/ERC20.sol";
// import "./interfaces/IERC20.sol";
// import "./interfaces/IUniswapFactory.sol";
// import "./interfaces/IUniswapExchange.sol";
import {AxiomV2Client} from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

contract ZeroSwap is AxiomV2Client {
    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 immutable QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 immutable SOURCE_CHAIN_ID;

    // Hyper Parameters
    int256 public scalingFactor = 1000000; // 1x scaling factor
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
    int256 public askPrice; // 1x scaling factor
    int256 public bidPrice; // 1x scaling factor
    int256 public lastAction1; // 0, 1, 2
    int256 public lastAction2; // 0, 1, 2

    // address public owner;
    // uint256 public totalSupply;
    // string public name;
    // string public symbol;
    // uint8 public decimals;
    // mapping(address => uint256) public balanceOf;
    // mapping(address => mapping(address => uint256)) public allowance;

    // Events
    // event Transfer(address indexed from, address indexed to, uint256 value);

    // event Approval(
    //     address indexed owner,
    //     address indexed spender,
    //     uint256 value
    // );

    event Swap();

    constructor(
        address _axiomV2QueryAddress,
        uint64 _callbackSourceChainId,
        bytes32 _axiomCallbackQuerySchema
    ) AxiomV2Client(_axiomV2QueryAddress) {
        QUERY_SCHEMA = _axiomCallbackQuerySchema;
        SOURCE_CHAIN_ID = _callbackSourceChainId;

        // QTable = new int256[][](2*windowSize+1);
        for (uint256 i = 0; i < 21; i++) {
            // QTable[i] = new int256[](9);
            for (uint256 j = 0; j < 9; j++) {
                QTable[i][j] = 0;
            }
        }

        // action1 = new int256[](3);
        // action2 = new int256[](3);
        action1[0] = -1;
        action1[1] = 0;
        action1[2] = 1;
        action2[0] = -1;
        action2[1] = 0;
        action2[2] = 1;

        // stateHistory = new int256[](2*windowSize);
        for (uint256 i = 0; i < 2*windowSize; i++) {
            stateHistory[i] = 0;
        }
        pointer = 0;
        imbalance = 0;
        midPrice = 100;
        priceDelta = 0;
        lastAction1 = 0;
        lastAction2 = 0;
        askPrice = 0;
        bidPrice = 0;
    }

    function _axiomV2Callback(
        uint64, /* sourceChainId */
        address callerAddr,
        bytes32, /* querySchema */
        uint256 queryId,
        bytes32[] calldata axiomResults,
        bytes calldata /* extraData */
    ) internal virtual override {

        // Parse results
        uint32 _indexN = uint32(uint256(axiomResults[0]));
        uint32 _indexA = uint32(uint256(axiomResults[1]));
        
        int256 _updatedQValue = int256(uint256(axiomResults[2]));
        int256 _swapValue = int256(uint256(axiomResults[3]));
        int256 _midPrice = int256(uint256(axiomResults[4]));
        int256 _priceDelta = int256(uint256(axiomResults[5]));
        int256 _askPrice = int256(uint256(axiomResults[6]));
        int256 _bidPrice = int256(uint256(axiomResults[7]));
        int256 _imbalance = int256(uint256(axiomResults[8]));

        QTable[_indexN][_indexA] = _updatedQValue;
        stateHistory[pointer] = _swapValue;
        pointer = (pointer + 1) % (2*windowSize);
        midPrice = _midPrice;
        priceDelta = _priceDelta;
        askPrice = _askPrice;
        bidPrice = _bidPrice;
        imbalance = _imbalance;

        // Swap logic below

        // address userEventAddress = address(uint160(uint256(axiomResults[0])));
        // uint32 blockNumber = uint32(uint256(axiomResults[1]));
        // address uniV3PoolUniWethAddr = address(uint160(uint256(axiomResults[2])));

        // // Validate the results
        // require(userEventAddress == callerAddr, "Autonomous Airdrop: Invalid user address for event");
        // require(
        //     blockNumber >= MIN_BLOCK_NUMBER,
        //     "Autonomous Airdrop: Block number for transaction receipt must be 4000000 or greater"
        // );
        // require(
        //     uniV3PoolUniWethAddr == UNIV3_POOL_UNI_WETH,
        //     "Autonomous Airdrop: Address that emitted `Swap` event is not the UniV3 UNI-WETH pool address"
        // );

        // // Transfer tokens to user
        // hasClaimed[callerAddr] = true;
        // uint256 numTokens = 100 * 10 ** 18;
        // token.transfer(callerAddr, numTokens);

        // emit ClaimAirdrop(callerAddr, queryId, numTokens, axiomResults);
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

    // function transfer(
    //     address _to,
    //     uint256 _value
    // ) external returns (bool success) {
    //     require(balanceOf[msg.sender] >= _value, "Insufficient balance");
    //     balanceOf[msg.sender] -= _value;
    //     balanceOf[_to] += _value;
    //     emit Transfer(msg.sender, _to, _value);
    //     success = true;
    // }

    // function approve(
    //     address _spender,
    //     uint256 _value
    // ) external returns (bool success) {
    //     allowance[msg.sender][_spender] = _value;
    //     emit Approval(msg.sender, _spender, _value);
    //     success = true;
    // }

    // function transferFrom(
    //     address _from,
    //     address _to,
    //     uint256 _value
    // ) external returns (bool success) {
    //     require(balanceOf[_from] >= _value, "Insufficient balance");
    //     require(
    //         allowance[_from][msg.sender] >= _value,
    //         "Insufficient allowance"
    //     );
    //     balanceOf[_from] -= _value;
    //     balanceOf[_to] += _value;
    //     allowance[_from][msg.sender] -= _value;
    //     emit Transfer(_from, _to, _value);
    //     success = true;
    // }
}
