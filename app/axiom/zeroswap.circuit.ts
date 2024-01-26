import {
    addToCallback,
    CircuitValue,
    constant,
    poseidon,
    pow,
    sub,
    add,
    mul,
    div,
    getStorage,
    sum,
    mod,
    getHeader,
    isEqual,
} from "@axiom-crypto/client";

/// For type safety, define the input types to your circuit here.
/// These should be the _variable_ inputs to your circuit. Constants can be hard-coded into the circuit itself.
export interface CircuitInputs {
    value: CircuitValue;
    address: CircuitValue;
    direction: CircuitValue;
    contractAddress: CircuitValue;
    latestBlockNumber: CircuitValue;
}

// The function name `circuit` is searched for by default by our Axiom CLI; if you decide to 
// change the function name, you'll also need to ensure that you also pass the Axiom CLI flag 
// `-f <circuitFunctionName>` for it to work
export const circuit = async (inputs: CircuitInputs) => {
    // initialize a map, from 0, 1, 2 to -1, 0, 1, respectively
    const zero = constant(0);
    const one = constant(1);
    const two = constant(2);
    // Read data from the contract's slot
    const storage: Storage = getStorage(inputs.latestBlockNumber, inputs.contractAddress);
    const scalingFactor: CircuitValue = await storage.slot(3);
    const windowSize: CircuitValue = await storage.slot(4);
    const alpha: CircuitValue = await storage.slot(5);
    const gamma: CircuitValue = await storage.slot(6);
    const epsilon: CircuitValue = await storage.slot(7);
    const mu: CircuitValue = await storage.slot(8);
    let QTable: Array<Array<CircuitValue>> = [];
    for (let i = 0; i < 21; i++) {
        QTable.push([]);
    }
    for (let i = 0; i < 21; i++) {
        for (let j = 0; j < 9; j++) {
            QTable[i].push(await storage.slot(9 + i * 9 + j));
        }
    }
    let stateHistory: Array<CircuitValue> = [];
    for (let i = 0; i < 20; i++) {
        stateHistory.push(await storage.slot(204 + i));
    }
    let pointer: number = await storage.slot(224);

    const imbalance: number = await storage.slot(225);
    const midPrice: CircuitValue = await storage.slot(226);
    const priceDelta: CircuitValue = await storage.slot(227);
    const askPrice: CircuitValue = await storage.slot(228);
    const bidPrice: CircuitValue = await storage.slot(229);
    const lastAction1: number = await storage.slot(230);
    const lastAction2: number = await storage.slot(231);

    // Perform the Q-learning algorithm, 
    // pay attention to the scaling factor
    stateHistory[pointer] = inputs.value;
    const newImbalance: CircuitValue = sum(stateHistory);
    const reward = sub( // 1x scaling factor
        sub(
            0,
            mul(
                pow(newImbalance, 2),
                scalingFactor
            )
        ),
        mul(
            div(mu, scalingFactor),
            div(
                pow(
                    sub(askPrice, bidPrice),
                    2
                ),
                scalingFactor
            )
        )
    );
    let maxIndex = 0;
    for (let i = 0; i < 9; i++) {
        if (QTable[newImbalance.number()][i] > QTable[newImbalance.number()][maxIndex]) {
            maxIndex = i;
        }
    }
    const newQValue = add( // 1x scaling factor
        QTable[imbalance][lastAction1*3+lastAction2],
        div(
            mul(
                alpha,
                add(
                    reward,
                    sub(
                        div(
                            mul(
                                gamma,
                                QTable[newImbalance.number()][maxIndex]
                            ),
                            scalingFactor
                        ),
                        QTable[imbalance][lastAction1*3+lastAction2]
                    )
                )
            ),
            scalingFactor
        )
    )

    // Get a random number
    const header = getHeader(inputs.latestBlockNumber);
    const stateRoot = await header.stateRoot();
    const randomNumber = mod(poseidon(stateRoot.toCircuitValue()), scalingFactor)
    let action1: CircuitValue = constant(0);
    let action2: CircuitValue = constant(0);

    if (randomNumber < epsilon) { // random action
        const transactionsRoot = await header.transactionsRoot();
        const receiptsRoot = await header.receiptsRoot();
        // get map value
        action1 = mod(poseidon(transactionsRoot.toCircuitValue()), 3)
        action2 = mod(poseidon(receiptsRoot.toCircuitValue()), 3)
    } else { // greedy action
        // maxIndex
        action1 = div(maxIndex, 3);
        action2 = mod(maxIndex, 3);
    }
    addToCallback(action1);
    addToCallback(action2);
    if (isEqual(action1, zero)) {
        action1 = constant(-1);
    } else if (isEqual(action1, one)) {
        action1 = constant(0);
    } else if (isEqual(action1, two)) {
        action1 = constant(1);
    }
    if (isEqual(action2, zero)) {
        action2 = constant(-1);
    } else if (isEqual(action2, one)) {
        action2 = constant(0);
    } else if (isEqual(action2, two)) {
        action2 = constant(1);
    }
    const newMidPrice = add( // 1x scaling factor
        midPrice,
        mul(
            action1,
            scalingFactor
        )
    );
    const newPriceDelta = add( // 1x scaling factor
        priceDelta,
        mul(
            action2,
            scalingFactor
        )
    );
    const newAskPrice = add( // 1x scaling factor
        newMidPrice,
        newPriceDelta
    );
    const newBidPrice = sub( // 1x scaling factor
        newMidPrice,
        newPriceDelta
    );
    
    addToCallback(constant(imbalance));
    addToCallback(constant(maxIndex));
    addToCallback(newQValue);
    addToCallback(inputs.value);
    addToCallback(newMidPrice);
    addToCallback(newPriceDelta);
    addToCallback(newAskPrice);
    addToCallback(newBidPrice);
    addToCallback(newImbalance);
    
    addToCallback(inputs.address);
    addToCallback(inputs.direction);
};