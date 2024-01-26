# ZeroSwap Implementation with Axiom framework

In this repository, we implement the Q-learning algorithm in the ZeroSwap using the Axiom and Solidity. 

This is built based on the repository https://github.com/axiom-crypto/autonomous-airdrop-example, and the paper https://arxiv.org/pdf/2310.09413.pdf

## Contracts on Sepolia

The two tokens are deployed to:

ZeroSwapToken1(ZST1): 0x6bEb2A6ee911C3Bb9F8295826565D9fa62edd2B2

ZeroSwapToken2(ZST2): 0x27886F651AC1c2745e1116bf350E48eB5e70FCCe

The ZeroSwap contract is deployed to 0xDEBF7e4F81A8eE82Dd86a2B5554fa922935830A1

NOTICE: use the [unit converter](https://sepolia.etherscan.io/unitconverter) to swap.

## Algorithm Hyper Parameter Setting

windowSize = 10

alpha = 0.3 learning rate

sigma = 1 price jump

epsilon = 0.99 probability of exploration vs exploitation - decays over time, this is only the starting epsilon

mu = 18

gamma = 0.99 discount rate of future rewards

## Frontend

Users make requests to swap some tokens. The input from the frontend is the same as the uniswap. And there is also a random number, and two random actions. We use the hash of the latest block to generate the random numbers. 

## ZK Circuit

The ZK Circuit is responsible for computing the new imbalance, the reward, and the update of the Q table. At the same time, the circuit should use the new Q table to compute the ask and bid price, and send all the results to the contract on chain.

### Get the data from the chain

It should get all the data maintained by the smart contract.

### Perform the computation

1. Compute the new imbalance
2. Compute the reward
3. Compute a new value of the Q table
4. Choose an action (whether it is the random action or the action based on the Q table)
5. Compute the mid price, price delta, ask price and the bid price. 
6. Send data to the callback contract

## ZeroSwap Contract

### Contract Storage

1. Q Table
2. Actions
3. PrevTransaction Information(array): Value (positive in, negative out)
4. Queue Pointer (next item to be replaced)
5. Imbalance
6. Mid Price
7. Price Delta
8. Ask Price
9. Bid Price
10. Hyper Parameters


| Name            | Type            | Slot | Offset | Bytes | Contract                  |
|-----------------|-----------------|------|--------|-------|---------------------------|
| _owner          | address         | 0    | 0      | 20    | src/ZeroSwap.sol:ZeroSwap |
| QUERY_SCHEMA    | bytes32         | 1    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| SOURCE_CHAIN_ID | uint64          | 2    | 0      | 8     | src/ZeroSwap.sol:ZeroSwap |
| scalingFactor   | uint256         | 3    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| windowSize      | uint256         | 4    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| alpha           | int256          | 5    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| gamma           | int256          | 6    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| epsilon         | int256          | 7    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| mu              | int256          | 8    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| QTable          | int256[9][21]   | 9    | 0      | 6048  | src/ZeroSwap.sol:ZeroSwap |
| action1         | int256[3]       | 198  | 0      | 96    | src/ZeroSwap.sol:ZeroSwap |
| action2         | int256[3]       | 201  | 0      | 96    | src/ZeroSwap.sol:ZeroSwap |
| stateHistory    | int256[20]      | 204  | 0      | 640   | src/ZeroSwap.sol:ZeroSwap |
| pointer         | uint256         | 224  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| imbalance       | int256          | 225  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| midPrice        | int256          | 226  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| priceDelta      | int256          | 227  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| askPrice        | uint256         | 228  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| bidPrice        | uint256         | 229  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| lastAction1     | int256          | 230  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| lastAction2     | int256          | 231  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| token1          | contract IERC20 | 232  | 0      | 20    | src/ZeroSwap.sol:ZeroSwap |
| token2          | contract IERC20 | 233  | 0      | 20    | src/ZeroSwap.sol:ZeroSwap |

### Input of the Swap Function

1. updated Q table
    1. index n (uint32)
    2. index a (uint32)
    3. value (int256)
2. new swap value (int256)
3. updated mid price (int256)
4. updated price delta (int256)
5. updated ask price (uint256)
6. updated bid price (uint256)
7. updated imbalance (int256)
8. user address (address)
9. swap direction (uint256)
10. last action (int256)

### Computation inside the Swap Function

1. update the Q table
2. replace the pointer's value with the new swap value
3. update the mid price, price delta, ask price, bid price, and the imbalance
4. perform the swap

## Roadmap

1. Implement the core algorithm of Q-learning (finished)
    1. smart contract (finished)
    2. client circuit (finished)
2. Test with Foundry (finished)
3. Implement the swap logic (finished)
4. Implement the frontend (pending)

## Existing Problems

1. How to index multi-dimensional arrays in the client circuit? (solved)
2. Can we get the reference of elements in the array and change them? (solved, just copy)
3. By now, some array operations in the client circuit are not using the Axiom datatype/primitives. (use the .number() to index and use it as the boolean value) (solved)
4. How to test the convergence without spending lots of testETH? How to skip the Axiom verifier and prover and just to verify my codes?

## Error Message

1. The client circuit must have a addToCallback function, otherwise it will have an error message throw new Error("Could not find import name");
2. The output of the storage.slot is CircuitValue256, we should convert it if we want to use CircuitValue.

## Circuit

npx axiom circuit compile app/axiom/zeroswap.circuit.ts --inputs app/axiom/data/inputs.json --provider $PROVIDER_URI_SEPOLIA
npx axiom circuit prove app/axiom/zeroswap.circuit.ts --inputs app/axiom/data/inputs.json --provider $PROVIDER_URI_SEPOLIA