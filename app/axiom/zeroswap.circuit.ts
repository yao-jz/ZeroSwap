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
    isLessThan,
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
    // Read data from the contract's slot
    const storage: Storage = getStorage(inputs.latestBlockNumber, inputs.contractAddress);
    const scalingFactor: CircuitValue = (await storage.slot(3)).toCircuitValue();
    const windowSize: CircuitValue = (await storage.slot(4)).toCircuitValue();
    const alpha: CircuitValue = (await storage.slot(5)).toCircuitValue();
    const gamma: CircuitValue = (await storage.slot(6)).toCircuitValue();
    const epsilon: CircuitValue = (await storage.slot(7)).toCircuitValue();
    const mu: CircuitValue = (await storage.slot(8)).toCircuitValue();
    // console.log(mu);
    // let QTable: Array<Array<CircuitValue>> = [];
    // for (let i = 0; i < 21; i++) {
    //     QTable.push([]);
    // }
    // for (let i = 0; i < 21; i++) {
    //     for (let j = 0; j < 9; j++) {
    //         QTable[i].push((await storage.slot(9 + i * 9 + j)).toCircuitValue());
    //     }
    // }
    const pointer: number = (await storage.slot(224)).toCircuitValue().number();
    let newImbalance = inputs.value;
    for (let i = 0; i < 20; i++) {
        if (i == pointer) continue;
        newImbalance = add(
            newImbalance,
            (await storage.slot(204 + i)).toCircuitValue()
        );
    }
    // let stateHistory: Array<CircuitValue> = [];
    // for (let i = 0; i < 20; i++) {
    //     stateHistory.push((await storage.slot(204 + i)).toCircuitValue());
    // }
    // const pointer: number = (await storage.slot(224)).toCircuitValue().number();
    const imbalance: number = (await storage.slot(225)).toCircuitValue().number();
    const midPrice: CircuitValue = (await storage.slot(226)).toCircuitValue();
    const priceDelta: CircuitValue = (await storage.slot(227)).toCircuitValue();
    const askPrice: CircuitValue = (await storage.slot(228)).toCircuitValue();
    const bidPrice: CircuitValue = (await storage.slot(229)).toCircuitValue();
    const lastAction1: number = (await storage.slot(230)).toCircuitValue().number();
    const lastAction2: number = (await storage.slot(231)).toCircuitValue().number();

    // Perform the Q-learning algorithm, 
    // pay attention to the scaling factor
    // stateHistory[pointer] = inputs.value;
    // const newImbalance: CircuitValue = sum(stateHistory);
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
    let maxQTableValue: CircuitValue = (await storage.slot(9 + newImbalance.number() * 9 + maxIndex)).toCircuitValue();
    for (let i = 0; i < 9; i++) {
        let thisQTableValue: CircuitValue = (await storage.slot(9 + newImbalance.number() * 9 + i)).toCircuitValue();
        if (isLessThan(maxQTableValue, thisQTableValue).number()) {
            maxIndex = i;
            maxQTableValue = thisQTableValue;
        }
        // if (QTable[newImbalance.number()][i] > QTable[newImbalance.number()][maxIndex]) {
        //     maxIndex = i;
        // }
    }
    const newQValue = add( // 1x scaling factor
        // QTable[imbalance][lastAction1*3+lastAction2],
        (await storage.slot(9 + imbalance * 9 + lastAction1 * 3 + lastAction2)).toCircuitValue(),
        div(
            mul(
                alpha,
                add(
                    reward,
                    sub(
                        div(
                            mul(
                                gamma,
                                maxQTableValue
                                // QTable[newImbalance.number()][maxIndex]
                            ),
                            scalingFactor
                        ),
                        (await storage.slot(9 + imbalance * 9 + lastAction1 * 3 + lastAction2)).toCircuitValue()
                        // QTable[imbalance][lastAction1*3+lastAction2]
                    )
                )
            ),
            scalingFactor
        )
    )

    // Get a random number
    const header = getHeader(inputs.latestBlockNumber);
    const stateRoot = await header.stateRoot();
    const randomNumber = mod(poseidon(stateRoot.lo()), scalingFactor)
    let action1: CircuitValue = constant(0);
    let action2: CircuitValue = constant(0);
    if (randomNumber < epsilon) { // random action
        const transactionsRoot = await header.transactionsRoot();
        const receiptsRoot = await header.receiptsRoot();
        // get map value
        action1 = mod(poseidon(transactionsRoot.lo()), 3)
        action2 = mod(poseidon(receiptsRoot.lo()), 3)
    } else { // greedy action
        // maxIndex
        action1 = div(maxIndex, 3);
        action2 = mod(maxIndex, 3);
    }
    addToCallback(action1);
    addToCallback(action2);
    const newMidPrice = add( // 1x scaling factor
        midPrice,
        mul(
            sub(
                action1,
                1
            ),
            scalingFactor
        )
    );
    const newPriceDelta = add( // 1x scaling factor
        priceDelta,
        mul(
            sub(
                action2,
                1
            ),
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
    addToCallback(inputs.direction); // 0 for buy token2, 1 for buy token1
};