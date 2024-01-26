// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AxiomTest, AxiomVm} from "@axiom-crypto/v2-periphery/test/AxiomTest.sol";
import {ZeroSwap} from "../src/ZeroSwap.sol";

contract ContractBTest is AxiomTest {
    uint256 testNumber;
    ZeroSwap zeroSwap;

    function setUp() public {
        _createSelectForkAndSetupAxiom("sepolia", 5_103_100);

        inputPath = "app/axiom/data/inputs.json";
        querySchema = axiomVm.compile(
            "app/axiom/zeroswap.circuit.ts",
            inputPath
        );

        zeroSwap = new ZeroSwap(
            axiomV2QueryAddress,
            uint64(block.chainid),
            querySchema
        );
    }

    function test_axiomSendQueryWithArgs() public {
        AxiomVm.AxiomSendQueryArgs memory args = axiomVm.sendQueryArgs(
            inputPath,
            address(zeroSwap),
            callbackExtraData,
            feeData
        );
        axiomV2Query.sendQuery{value: args.value}(
            args.sourceChainId,
            args.dataQueryHash,
            args.computeQuery,
            args.callback,
            args.feeData,
            args.userSalt,
            args.refundee,
            args.dataQuery
        );
    }

    function test_AxiomCallbackWithArgs() public {
        AxiomVm.AxiomFulfillCallbackArgs memory args = axiomVm
            .fulfillCallbackArgs(
                inputPath,
                address(zeroSwap),
                callbackExtraData,
                feeData,
                msg.sender
            );
        axiomVm.prankCallback(args);
    }
}
