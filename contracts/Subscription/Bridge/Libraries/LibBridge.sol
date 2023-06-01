// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {IERC20} from "./../../Interfaces/IERC20.sol";
import {ILiFi, StargateData, AmarokData} from "./../../Interfaces/ILiFi.sol";
import {LibSwap} from "./../../Interfaces/LibSwap.sol";
import {BridgeFacet} from "../../Router/Facets/BridgeFacet.sol";
import {ILiFiDiamond} from "../Interfaces/ILiFiDiamond.sol";

struct PaymentParameters {
    uint256 chainId;
    uint256 subscriptionManagerId;
    uint8 subscriptionId;
    uint256 priceInSubToken;
    IERC20 token;
}

struct UserBridgeData {
    /// @notice last payment in timestamp to define when bot can take in the account
    uint256 nextPaymentTime;
    /// @notice Duration of the sub in secs
    uint256 subscriptionDuration;
    /// @notice Limit in subtoken
    uint256 subscriptionLimit;
}

struct Storage {
    mapping(uint256 => mapping(uint256 => mapping(address => UserBridgeData))) users;
}

library LibBridge {
    bytes32 internal constant NAMESPACE = keccak256("com.cicleo.facets.bridge");

    /// @notice Get chain id of the smartcontract
    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function tokenPayment(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData
    ) internal {
        require(
            getStorage()
            .users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                msg.sender
            ].subscriptionLimit >= paymentParams.priceInSubToken,
            "Amount too high"
        );

        uint256 balanceBefore = paymentParams.token.balanceOf(address(this));

        paymentParams.token.transferFrom(
            user,
            address(this),
            _bridgeData.minAmount
        );

        getStorage()
        .users[paymentParams.chainId][paymentParams.subscriptionManagerId][user]
            .nextPaymentTime =
            block.timestamp +
            getStorage()
            .users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                user
            ].subscriptionDuration;

        //Verify if we received correct amount of token
        require(
            paymentParams.token.balanceOf(address(this)) - balanceBefore >=
                _bridgeData.minAmount,
            "Transfer failed"
        );

        //Approve the LiFi Diamond to spend the token
        paymentParams.token.approve(
            0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE,
            _bridgeData.minAmount
        );
    }

    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param signature Signature of the user
    function getSubscribeDestinationCalldata(
        PaymentParameters memory paymentParams,
        address user,
        address referral,
        bytes memory signature
    ) internal pure returns (bytes memory) {
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

    function verifyRenew(
        PaymentParameters memory paymentParams,
        address user
    ) internal view {
        require(
            getStorage()
            .users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                user
            ].nextPaymentTime < block.timestamp,
            "Subscription is not expired"
        );
    }

    function setSubscriptionDuration(
        PaymentParameters memory paymentParams,
        uint256 duration
    ) internal {
        getStorage()
        .users[paymentParams.chainId][paymentParams.subscriptionManagerId][
            msg.sender
        ].subscriptionDuration = duration;
    }

    //----Diamond storage functions-------------------------------------//

    /// @dev fetch local storage
    function getStorage() private pure returns (Storage storage s) {
        bytes32 namespace = NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := namespace
        }
    }
}
