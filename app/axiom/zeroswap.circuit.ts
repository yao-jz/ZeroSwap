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
    select,
    CircuitValue256,
    neg,
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
    const scalingFactor: CircuitValue = (await storage.slot(constant(3))).toCircuitValue();
    const windowSize: CircuitValue = (await storage.slot(constant(4))).toCircuitValue();
    const alpha: CircuitValue = (await storage.slot(constant(5))).toCircuitValue();
    const gamma: CircuitValue = (await storage.slot(constant(6))).toCircuitValue();
    const epsilon: CircuitValue = (await storage.slot(constant(7))).toCircuitValue();
    const mu: CircuitValue = (await storage.slot(constant(8))).toCircuitValue();
    const pointer: CircuitValue = (await storage.slot(constant(224))).toCircuitValue();
    let newImbalance = inputs.value;
    for (let i = 0; i < 20; i++) {
        newImbalance = add(
            newImbalance,
            select(constant(0), (await storage.slot(constant(204 + i))).toCircuitValue(), isEqual(pointer, constant(i)))
        );
    }
    const imbalance: CircuitValue = (await storage.slot(constant(225))).toCircuitValue();
    const midPrice: CircuitValue = (await storage.slot(constant(226))).toCircuitValue();
    const priceDelta: CircuitValue = (await storage.slot(constant(227))).toCircuitValue();
    const askPrice: CircuitValue = (await storage.slot(constant(228))).toCircuitValue();
    const bidPrice: CircuitValue = (await storage.slot(constant(229))).toCircuitValue();
    const lastAction1: CircuitValue = (await storage.slot(constant(230))).toCircuitValue();
    const lastAction2: CircuitValue = (await storage.slot(constant(231))).toCircuitValue();
    // // Perform the Q-learning algorithm, 
    // // pay attention to the scaling factor
    const reward = sub( // 1x scaling factor
        sub(
            constant(0),
            mul(
                pow(newImbalance, constant(2)),
                scalingFactor
            )
        ),
        mul(
            div(mu, scalingFactor),
            div(
                pow(
                    sub(askPrice, bidPrice),
                    constant(2)
                ),
                scalingFactor
            )
        )
    );
    console.log("reward", reward);
    console.log("scalingFactor", scalingFactor);
    console.log("div(reward,scalingFactor)", div(reward,scalingFactor));
    // OUTPUT
    // reward CircuitValue {
    //     _circuit: Halo2LibWasm { __wbg_ptr: 6556120 },
    //     _cell: 20508,
    //     _value: 21888242871839275222246405745257275088548364400416034343698204186575806775617n
    //   }
    //   reward.number() 2.1888242871839275e+76
    //   scalingFactor CircuitValue {
    //     _circuit: Halo2LibWasm { __wbg_ptr: 6556120 },
    //     _cell: 200,
    //     _value: 1000000n
    //   }
    //   scalingFactor.number() 1000000
    //   div(reward,scalingFactor) CircuitValue {
    //     _circuit: Halo2LibWasm { __wbg_ptr: 6556120 },
    //     _cell: 20515,
    //     _value: 21888242871839275222246405745257275088548364400416034343698204186575806n
    //   }
    let maxIndex: CircuitValue = constant(0);
    let maxQTableValue: CircuitValue = (await storage.slot(
        add(
            add(
                constant(9),
                mul(
                    newImbalance,
                    constant(9)
                )
            ),
            maxIndex
        )
    )).toCircuitValue();
    for (let i = 0; i < 9; i++) {
        let thisQTableValue: CircuitValue = (await storage.slot(
            add(
                add(
                    constant(9),
                    mul(
                        newImbalance,
                        constant(9)
                    )
                ),
                constant(i)
            )
        )).toCircuitValue();
        maxIndex = select(constant(i), maxIndex, isLessThan(maxQTableValue, thisQTableValue));
        maxQTableValue = select(thisQTableValue, maxQTableValue, isLessThan(maxQTableValue, thisQTableValue));
    }
    const newQValue = add( // 1x scaling factor
        // QTable[imbalance][lastAction1*3+lastAction2],
        (await storage.slot(
            add(
                add(
                    constant(9),
                    mul(
                        imbalance,
                        constant(9)
                    )
                ),
                add(
                    mul(
                        lastAction1,
                        constant(3)
                    ),
                    lastAction2
                )
            )
        )).toCircuitValue(),
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
                        (await storage.slot(
                            add(
                                add(
                                    constant(9),
                                    mul(
                                        imbalance,
                                        constant(9)
                                    )
                                ),
                                add(
                                    mul(
                                        lastAction1,
                                        constant(3)
                                    ),
                                    lastAction2
                                )
                            )
                        )).toCircuitValue()
                        // QTable[imbalance][lastAction1*3+lastAction2]
                    )
                )
            ),
            scalingFactor
        )
    )

    // Get a random number
    const header = getHeader(inputs.latestBlockNumber);
    const stateRoot: CircuitValue256 = await header.stateRoot();
    // const randomNumber: CircuitValue = mod(poseidon(stateRoot.lo()), scalingFactor);
    const randomNumber: CircuitValue = constant(0);
    const transactionsRoot: CircuitValue256 = await header.transactionsRoot();
    const receiptsRoot: CircuitValue256 = await header.receiptsRoot();
    // const action1 = select(mod(poseidon(transactionsRoot.lo()), constant(3)), div(maxIndex, constant(3)), isLessThan(randomNumber, epsilon));
    // const action2 = select(mod(poseidon(receiptsRoot.lo()), constant(3)), mod(maxIndex, constant(3)), isLessThan(randomNumber, epsilon));
    // const temp1: CircuitValue = poseidon(receiptsRoot.lo());
    // const temp = mod(temp1, constant(3));
    const action1 = select(constant(1), div(maxIndex, constant(3)), isLessThan(randomNumber, epsilon));
    const action2 = select(constant(1), mod(maxIndex, constant(3)), isLessThan(randomNumber, epsilon));
    addToCallback(action1);
    addToCallback(action2);
    const newMidPrice = add( // 1x scaling factor
        midPrice,
        mul(
            sub(
                action1,
                constant(1)
            ),
            scalingFactor
        )
    );
    const newPriceDelta = add( // 1x scaling factor
        priceDelta,
        mul(
            sub(
                action2,
                constant(1)
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
    addToCallback(imbalance);
    addToCallback(maxIndex);
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