# ZeroSwap Implementation with Axiom framework

This is built based on the repository https://github.com/axiom-crypto/autonomous-airdrop-example

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
8. Hyper Parameters

### Input of the Swap Function

1. updated Q table
    1. index n
    2. index a
    3. value
2. new swap value
3. updated mid price
4. updated price delta
5. updated ask price
6. updated bid price
7. updated imbalance

### Computation inside the Swap Function

1. update the Q table
2. replace the pointer's value with the new swap value
3. update the mid price, price delta, ask price, bid price, and the imbalance
4. perform the swap