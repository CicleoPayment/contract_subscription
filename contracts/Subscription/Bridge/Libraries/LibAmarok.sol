// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibBridge, PaymentParameters, LibSwap} from "./LibBridge.sol";

library LibAmarok {
    /// @notice Change the destination call from LiFi parameter
    /// @param originalCalldata Original calldata
    /// @param dstCalldata Destination calldata
    /// @return finalCallData New calldata
    function changeDestinationCalldata(
        bytes memory originalCalldata,
        bytes memory dstCalldata
    ) internal pure returns (bytes memory finalCallData) {
        (LibSwap.SwapData[] memory swapData, address receiver) = abi.decode(
            originalCalldata,
            (LibSwap.SwapData[], address)
        );

        //Change the last call data
        swapData[swapData.length - 1].callData = dstCalldata;

        return abi.encode(swapData, receiver);
    }

    function handleSubscriptionCallback(
        PaymentParameters memory paymentParams,
        address user,
        address referral,
        bytes memory signature,
        bytes memory originalCalldata
    ) internal pure returns (bytes memory) {
        return
            changeDestinationCalldata(
                originalCalldata,
                LibBridge.getSubscribeDestinationCalldata(
                    paymentParams,
                    user,
                    referral,
                    signature
                )
            );
    }

    function handleRenewCallback(
        PaymentParameters memory paymentParams,
        address user,
        bytes memory originalCalldata
    ) internal pure returns (bytes memory) {
        return
            changeDestinationCalldata(
                originalCalldata,
                LibBridge.getRenewDestinationCalldata(
                    user,
                    paymentParams.subscriptionManagerId
                )
            );
    }
}
