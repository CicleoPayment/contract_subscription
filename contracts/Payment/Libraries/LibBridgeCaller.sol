// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import "./../Interfaces/IERC20.sol";
import {ILiFi, StargateData, LibSwap} from "./../Interfaces/ILiFi.sol";
import "./../Facets/BridgeFacet.sol";

library LibBridgeCaller {
    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param signature Signature of the user
    function getPaymentDestinationCalldata(
        PaymentParameters memory paymentParams,
        address user,
        bytes memory signature
    ) public pure returns (bytes memory) {
        bytes4 selector = BridgeFacet.bridgePayment.selector;
        return abi.encodeWithSelector(selector, paymentParams, user, signature);
    }

    /// @notice Change the destination call from LiFi parameter
    /// @param originalCalldata Original calldata
    /// @param dstCalldata Destination calldata
    /// @return finalCallData New calldata
    function changeDestinationCalldata(
        bytes memory originalCalldata,
        bytes memory dstCalldata
    ) internal pure returns (bytes memory finalCallData) {
        (
            uint256 txId,
            LibSwap.SwapData[] memory swapData,
            address assetId,
            address receiver
        ) = abi.decode(
                originalCalldata,
                (uint256, LibSwap.SwapData[], address, address)
            );

        swapData[swapData.length - 1].callData = dstCalldata;

        return abi.encode(txId, swapData, assetId, receiver);
    }

    function handlePaymentCallback(
        PaymentParameters memory paymentParams,
        address user,
        bytes memory signature,
        bytes memory originalCalldata
    ) internal pure returns (bytes memory) {
        return
            changeDestinationCalldata(
                originalCalldata,
                getPaymentDestinationCalldata(paymentParams, user, signature)
            );
    }
}
