// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import "./Interfaces/IERC20.sol";
import {ILiFi, StargateData} from "./Interfaces/ILiFi.sol";
import {LibSwap} from "./Interfaces/LibSwap.sol";
import "./Router/facets/BridgeFacet.sol";

struct PaymentParameters {
    uint256 chainId;
    uint256 subscriptionManagerId;
    uint8 subscriptionId;
    uint256 priceInSubToken;
    IERC20 token;
}

library LibBridgeManager {

    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param subManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    /// @param price price in the subManager token amount
    /// @param signature Signature of the user
    function getSubscribeDestinationCalldata(
        address user,
        uint256 subManagerId,
        uint8 subscriptionId,
        uint256 paymentChainId,
        address paymentToken,
        uint256 price,
        address referral,
        bytes memory signature
    ) public pure returns (bytes memory) {
        bytes4 selector = BridgeFacet.bridgeSubscribe.selector;
        return
            abi.encodeWithSelector(
                selector,
                subManagerId,
                subscriptionId,
                user,
                paymentChainId,
                paymentToken,
                price,
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
        uint256 chainId,
        address referral,
        bytes memory signature,
        bytes memory originalCalldata
    ) internal pure returns (bytes memory) {
        return changeDestinationCalldata(
            originalCalldata,
            getSubscribeDestinationCalldata(
                user,
                paymentParams.subscriptionManagerId,
                paymentParams.subscriptionId,
                chainId,
                address(paymentParams.token),
                paymentParams.priceInSubToken,
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
        return changeDestinationCalldata(
            originalCalldata,
            getRenewDestinationCalldata(
                user,
                paymentParams.subscriptionManagerId
            )
        );
    }
}