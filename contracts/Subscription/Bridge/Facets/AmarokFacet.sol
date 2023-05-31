// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {LibBridge, UserBridgeData, PaymentParameters, ILiFi, ILiFiDiamond, LibSwap, AmarokData, Storage} from "../Libraries/LibBridge.sol";
import {IERC20} from "./../../Interfaces/IERC20.sol";

contract AmarokFacet {
    bytes32 internal constant NAMESPACE = keccak256("com.cicleo.facets.bridge");
    //----Event----------------------------------------------//

    struct BridgePaymentSpec {
        uint256 destChainId;
        uint256 subscriptionManagerId;
        uint8 subscriptionId;
        uint256 price;
    }

    /// @notice Event when a user pays for a subscription (first time or even renewing)
    event PaymentBridgeSubscription(
        address indexed user,
        BridgePaymentSpec indexed info
    );

    //----Internal function with sign part----------------------------------------------//

    //-----Bridge thing internal function

    function paymentWithBridgeWithAmarok(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        AmarokData memory _amarokData
    ) internal {
        //Do token transfer from and check if the amount is correct
        LibBridge.tokenPayment(paymentParams, user, _bridgeData);

        //Bridge the call to LiFi
        if (_swapData.length > 0) {
            ILiFiDiamond(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE)
                .swapAndStartBridgeTokensViaAmarok{value: msg.value}(
                _bridgeData,
                _swapData,
                _amarokData
            );
        } else {
            ILiFiDiamond(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE)
                .startBridgeTokensViaAmarok{value: msg.value}(
                _bridgeData,
                _amarokData
            );
        }

        emit PaymentBridgeSubscription(
            user,
            BridgePaymentSpec(
                paymentParams.chainId,
                paymentParams.subscriptionManagerId,
                paymentParams.subscriptionId,
                paymentParams.priceInSubToken
            )
        );
    }

    /// @notice Function to pay subscription with any coin on another chain
    function payFunctionWithBridgeWithAmarok(
        PaymentParameters memory paymentParams,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        AmarokData memory _amarokData,
        address referral,
        uint256 duration,
        bytes calldata signature
    ) external payable {
        paymentParams.chainId = LibBridge.getChainID();

        //Remplace the destination call by our one
        _amarokData.callData = LibBridge.handleSubscriptionCallback(
            paymentParams,
            msg.sender,
            referral,
            signature,
            _amarokData.callData
        );

        LibBridge.setSubscriptionDuration(paymentParams, duration);

        paymentWithBridgeWithAmarok(
            paymentParams,
            msg.sender,
            _bridgeData,
            _swapData,
            _amarokData
        );
    }

    function renewSubscriptionByBridgeWithAmarok(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        AmarokData memory _stargateData
    ) public payable {
        LibBridge.verifyRenew(paymentParams, user);

        //Remplace the destination call by our one
        _stargateData.callData = LibBridge.handleRenewCallback(
            paymentParams,
            user,
            _stargateData.callData
        );

        paymentWithBridgeWithAmarok(
            paymentParams,
            user,
            _bridgeData,
            _swapData,
            _stargateData
        );
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
