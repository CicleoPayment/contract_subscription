// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import {IERC20} from "./../Interfaces/IERC20.sol";
import {ILiFi, StargateData} from "./../Interfaces/ILiFi.sol";
import {LibSwap} from "./../Interfaces/LibSwap.sol";
import {BridgeFacet, PaymentParameters} from "../Facets/BridgeFacet.sol";

library LibBridgeManager {
    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param signature Signature of the user
    function getSubscribeDestinationCalldata(
        PaymentParameters memory paymentParams,
        address user,
        address referral,
        bytes memory signature
    ) public pure returns (bytes memory) {
        bytes4 selector = BridgeFacet.bridgeSubscribe.selector;
        return
            abi.encodeWithSelector(
                selector,
                paymentParams,
                user,
                referral,
                signature
            );
    }

    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param subManagerId Id of the submanager
    function getRenewDestinationCalldata(
        address user,
        uint256 subManagerId
    ) internal pure returns (bytes memory) {
        bytes4 selector = BridgeFacet.bridgeRenew.selector;
        return abi.encodeWithSelector(selector, subManagerId, user);
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
                getSubscribeDestinationCalldata(
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
                getRenewDestinationCalldata(
                    user,
                    paymentParams.subscriptionManagerId
                )
            );
    }
}
