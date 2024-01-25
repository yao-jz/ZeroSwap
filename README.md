# ZeroSwap Implementation with Axiom framework

In this repository, we implement the Q-learning algorithm in the ZeroSwap using the Axiom and Solidity. 

This is built based on the repository https://github.com/axiom-crypto/autonomous-airdrop-example, and the paper https://arxiv.org/pdf/2310.09413.pdf

There are three components: frontend, zk circuit, and the contract

Consider the simple implementation first, the swapping logic should refer to the Uniswap.

## Algorithm Hyper Parameter Setting

windowSize = 10
alpha = 0.3 learning rate
sigma = 1 price jump
epsilon = 0.99 probability of exploration vs exploitation - decays over time, this is only the starting epsilon
mu = 18
gamma = 0.99 discount rate of future rewards

## Frontend

Users make requests to swap some tokens. The input from the frontend is the same as the uniswap. And there is also a random number, and two random actions. (NOTICE: the random number should be generated with proof, but till now we don't know how to do this.)

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

### Contract slot

| Name          | Type          | Slot | Offset | Bytes | Contract                  |
|---------------|---------------|------|--------|-------|---------------------------|
| scalingFactor | int256        | 0    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| windowSize    | uint256       | 1    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| alpha         | int256        | 2    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| gamma         | int256        | 3    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| epsilon       | int256        | 4    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| sigma         | int256        | 5    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| mu            | int256        | 6    | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| QTable        | int256[9][21] | 7    | 0      | 6048  | src/ZeroSwap.sol:ZeroSwap |
| action1       | int256[3]     | 196  | 0      | 96    | src/ZeroSwap.sol:ZeroSwap |
| action2       | int256[3]     | 199  | 0      | 96    | src/ZeroSwap.sol:ZeroSwap |
| stateHistory  | int256[20]    | 202  | 0      | 640   | src/ZeroSwap.sol:ZeroSwap |
| pointer       | uint256       | 222  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| imbalance     | int256        | 223  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| midPrice      | int256        | 224  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| priceDelta    | int256        | 225  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| askPrice      | int256        | 226  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| bidPrice      | int256        | 227  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| lastAction1   | int256        | 228  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |
| lastAction2   | int256        | 229  | 0      | 32    | src/ZeroSwap.sol:ZeroSwap |

### Input of the Swap Function

1. updated Q table
    1. index n (uint32)
    2. index a (uint32)
    3. value (int256)
2. new swap value (int256)
3. updated mid price (int256)
4. updated price delta (int256)
5. updated ask price (int256)
6. updated bid price (int256)
7. updated imbalance (int256)

### Computation inside the Swap Function

1. update the Q table
2. replace the pointer's value with the new swap value
3. update the mid price, price delta, ask price, bid price, and the imbalance
4. perform the swap

## Roadmap

1. Implement the core algorithm of Q-learning
    1. smart contract (finished)
    2. client circuit (finished)
2. Implement the swap logic
3. Implement the frontend

## Existing Problems

1. How to index multi-dimensional arrays in the client circuit?
2. Can we get the reference of elements in the array and change them?