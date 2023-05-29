// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {ILiFi, StargateData, LibSwap} from "./../Interfaces/ILiFi.sol";
import {IERC20} from "./../Interfaces/IERC20.sol";
import {PaymentParameters} from "./BridgeFacet.sol";
import {LibAdmin} from "./../Libraries/LibAdmin.sol";
import {LibBridgeCaller} from "./../Libraries/LibBridgeCaller.sol";

/// @notice Interface of the LiFi Diamond
interface ILiFiDiamond {
    function startBridgeTokensViaStargate(
        ILiFi.BridgeData memory _bridgeData,
        StargateData calldata _stargateData
    ) external payable;

    function swapAndStartBridgeTokensViaStargate(
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData calldata _stargateData
    ) external payable;

    function validateDestinationCalldata(
        bytes calldata data,
        bytes calldata dstCalldata
    ) external pure returns (bool isValid);
}

interface ICicleoRouter {
    function bridgeSubscription(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address user,
        bytes memory signature
    ) external view returns (address);
}

struct UserBridgeData {
    /// @notice last payment in timestamp to define when bot can take in the account
    uint256 nextPaymentTime;
    /// @notice Duration of the sub in secs
    uint256 subscriptionDuration;
    /// @notice Limit in subtoken
    uint256 subscriptionLimit;
}

/// @title Cicleo Subscription Bridge Manager
/// @author Pol Epie
/// @notice This contract is used to permit the payment via LiFi
contract BridgeCallerFacet {
    //-----Event----------------------------------------------//

    /// @notice Event when the payment bridged is emited (on client payment chain so)
    event PaymentBridged(
        uint256 indexed paymentManagerId,
        address indexed user,
        uint256 indexed price,
        string name
    );

    //-----Bridge thing internal function

    function paymentWithBridge(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData,
        uint256 inPrice
    ) internal {
        uint256 balanceBefore = paymentParams.token.balanceOf(address(this));

        ILiFiDiamond lifi = ILiFiDiamond(
            0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE
        );

        paymentParams.token.transferFrom(user, address(this), inPrice);

        //Verify if we received correct amount of token
        require(
            paymentParams.token.balanceOf(address(this)) - balanceBefore >=
                inPrice,
            "Transfer failed"
        );

        //Approve the LiFi Diamond to spend the token
        paymentParams.token.approve(address(lifi), inPrice);

        require(msg.value == _stargateData.lzFee, "Error msg.value");

        //Bridge the call
        if (_swapData.length > 0) {
            lifi.swapAndStartBridgeTokensViaStargate{value: msg.value}(
                _bridgeData,
                _swapData,
                _stargateData
            );
        } else {
            lifi.startBridgeTokensViaStargate{value: msg.value}(
                _bridgeData,
                _stargateData
            );
        }
    }

    //-----Bridge pay external function

    /// @notice Function to pay subscription with any coin on another chain
    function payWithCicleoWithBridge(
        PaymentParameters memory paymentParams,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData,
        uint256 inPrice,
        bytes calldata signature
    ) external payable {
        paymentParams.chainId = LibAdmin.getChainID();

        //Remplace the destination call by our one
        _stargateData.callData = LibBridgeCaller.handlePaymentCallback(
            paymentParams,
            msg.sender,
            signature,
            _stargateData.callData
        );

        paymentWithBridge(
            paymentParams,
            msg.sender,
            _bridgeData,
            _swapData,
            _stargateData,
            inPrice
        );

        emit PaymentBridged(
            paymentParams.paymentManagerId,
            msg.sender,
            paymentParams.price,
            paymentParams.name
        );
    }
}
