import {
    addToCallback,
    CircuitValue,
    CircuitValue256,
    constant,
    witness,
    getReceipt,
    getTx,
  } from "@axiom-crypto/client";

/// For type safety, define the input types to your circuit here.
/// These should be the _variable_ inputs to your circuit. Constants can be hard-coded into the circuit itself.
export interface CircuitInputs {
    value: CircuitValue;
    address: CircuitValue;
    direction: CircuitValue;
}

// The function name `circuit` is searched for by default by our Axiom CLI; if you decide to 
// change the function name, you'll also need to ensure that you also pass the Axiom CLI flag 
// `-f <circuitFunctionName>` for it to work
export const circuit = async (inputs: CircuitInputs) => {
    
    const value = inputs.value;
    


    addToCallback(inputs.address);
    addToCallback(inputs.direction);
    addToCallback(inputs.value);
  };