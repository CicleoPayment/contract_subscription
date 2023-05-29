// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import {ILiFi, StargateData} from "./Interfaces/ILiFi.sol";
import {LibSwap} from "./Interfaces/LibSwap.sol";
import {IERC20} from "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";
import "./Libraries/LibBridgeManager.sol";

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
contract CicleoSubscriptionBridgeManager {
    /// @notice users Mapping of the networkID to a mapping of the subscription manager id to the user address to the user info
    mapping(uint256 => mapping(uint256 => mapping(address => UserBridgeData)))
        public users;

    /// @notice lifi diamond to bridge
    ILiFiDiamond public lifi;

    constructor(address _lifi) {
        lifi = ILiFiDiamond(_lifi);
    }

    /// @notice Event when a user change his subscription limit
    event EditSubscriptionLimit(
        address indexed user,
        uint256 indexed chainId,
        uint256 indexed subscriptionManagerId,
        uint256 amountMaxPerPeriod
    );

    /// @notice Get chain id of the smartcontract
    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /// @notice Edit the subscription limit
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param amountMaxPerPeriod New subscription price limit per period in the submanager token
    function changeSubscriptionLimit(
        uint256 chainId,
        uint256 subscriptionManagerId,
        uint256 amountMaxPerPeriod
    ) external {
        users[chainId][subscriptionManagerId][msg.sender]
            .subscriptionLimit = amountMaxPerPeriod;

        emit EditSubscriptionLimit(
            msg.sender,
            chainId,
            subscriptionManagerId,
            amountMaxPerPeriod
        );
    }

    //-----Bridge thing internal function

    function paymentWithBridge(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData
    ) internal {
        uint256 balanceBefore = paymentParams.token.balanceOf(address(this));

        paymentParams.token.transferFrom(
            user,
            address(this),
            _bridgeData.minAmount
        );

        users[paymentParams.chainId][paymentParams.subscriptionManagerId][user]
            .nextPaymentTime =
            block.timestamp +
            users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                user
            ].subscriptionDuration;

        //Verify if we received correct amount of token
        require(
            paymentParams.token.balanceOf(address(this)) - balanceBefore >=
                _bridgeData.minAmount,
            "Transfer failed"
        );

        //Approve the LiFi Diamond to spend the token
        paymentParams.token.approve(address(lifi), _bridgeData.minAmount);

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
    function payFunctionWithBridge(
        PaymentParameters memory paymentParams,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData,
        address referral,
        uint256 duration,
        bytes calldata signature
    ) external payable {
        require(
            users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                msg.sender
            ].subscriptionLimit >= paymentParams.priceInSubToken,
            "Amount too high"
        );

        paymentParams.chainId = getChainID();

        //Remplace the destination call by our one
        _stargateData.callData = LibBridgeManager.handleSubscriptionCallback(
            paymentParams,
            msg.sender,
            referral,
            signature,
            _stargateData.callData
        );

        users[paymentParams.chainId][paymentParams.subscriptionManagerId][
            msg.sender
        ].subscriptionDuration = duration;

        paymentWithBridge(
            paymentParams,
            msg.sender,
            _bridgeData,
            _swapData,
            _stargateData
        );
    }

    function renewSubscriptionByBridge(
        PaymentParameters memory paymentParams,
        address user,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData
    ) public payable {
        require(
            users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                user
            ].subscriptionLimit >= paymentParams.priceInSubToken,
            "Amount too high"
        );

        require(
            users[paymentParams.chainId][paymentParams.subscriptionManagerId][
                user
            ].nextPaymentTime < block.timestamp,
            "Too late"
        );

        //Remplace the destination call by our one
        _stargateData.callData = LibBridgeManager.handleRenewCallback(
            paymentParams,
            user,
            _stargateData.callData
        );

        paymentWithBridge(
            paymentParams,
            user,
            _bridgeData,
            _swapData,
            _stargateData
        );
    }
}
