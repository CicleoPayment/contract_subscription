// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import {ILiFi, StargateData} from "./Interfaces/ILiFi.sol";
import {LibSwap} from "./Interfaces/LibSwap.sol";
import "hardhat/console.sol";
import "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";
import "./Router/facets/BridgeFacet.sol";

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

/// @title Cicleo Subscription Bridge Manager
/// @author Pol Epie
/// @notice This contract is used to permit the payment via LiFi
contract CicleoSubscriptionBridgeManager {
    /// @notice users Mapping of the networkID to a mapping of the subscription manager id to the user address to the subscription approval
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public usersSubscriptionLimit;

    /// @notice Mapping of the networkID to a mapping of the subscription manager id to last payment in timestamp to define when bot can take in the account
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) lastPayment;

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
        usersSubscriptionLimit[chainId][subscriptionManagerId][
            msg.sender
        ] = amountMaxPerPeriod;

        emit EditSubscriptionLimit(
            msg.sender,
            chainId,
            subscriptionManagerId,
            amountMaxPerPeriod
        );
    }

    //-----Bridge thing internal function

    /// @notice Encode the destination calldata
    /// @param user User to pay the subscription
    /// @param subManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
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
    ) public pure returns (bytes memory) {
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
    ) public pure returns (bytes memory finalCallData) {
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

    //-----Bridge pay external function

    /// @notice Function to pay subscription with any coin on another chain
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param token Token used to pay the subscription
    function payFunctionWithBridge(
        uint256 chainId,
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        IERC20 token,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData,
        address referral,
        bytes calldata signature
    ) external payable {
        require(
            usersSubscriptionLimit[chainId][subscriptionManagerId][
                msg.sender
            ] >= _bridgeData.minAmount,
            "Amount too high"
        );

        uint256 balanceBefore = token.balanceOf(address(this));

        token.transferFrom(msg.sender, address(this), _bridgeData.minAmount);

        //Verify if we received correct amount of token
        require(
            token.balanceOf(address(this)) - balanceBefore >= _bridgeData.minAmount,
            "Transfer failed"
        );

        //Approve the LiFi Diamond to spend the token
        token.approve(address(lifi), _bridgeData.minAmount);

        //Prepare the call to do on the dest chain
        bytes memory destCall = getSubscribeDestinationCalldata(
            msg.sender,
            subscriptionManagerId,
            subscriptionId,
            LibAdmin.getChainID(),
            address(token),
            _bridgeData.minAmount,
            referral,
            signature
        );

        //Remplace the destination by our one
        bytes memory newCalldata = changeDestinationCalldata(
            _stargateData.callData,
            destCall
        );

        _stargateData.callData = newCalldata;

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

    function renewSubscriptionByBridge(
        uint256 subscriptionManagerId,
        uint256 chainId,
        address user,
        IERC20 token,
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        StargateData memory _stargateData
    ) public payable {
        uint256 price = _bridgeData.minAmount;

        require(
            usersSubscriptionLimit[chainId][subscriptionManagerId][
                user
            ] >= _stargateData.minAmountLD,
            "Amount too high"
        );

        uint256 balanceBefore = token.balanceOf(address(this));

        token.transferFrom(user, address(this), price);

        //Verify if we received correct amount of token
        require(token.balanceOf(address(this)) - balanceBefore >= price, "Transfer failed");

        //Approve the LiFi Diamond to spend the token
        token.approve(address(lifi), price);

        //Prepare the call to do on the dest chain
        bytes memory destCall = getRenewDestinationCalldata(
            user,
            subscriptionManagerId
        );

        //Remplace the destination by our one
        bytes memory newCalldata = changeDestinationCalldata(
            _stargateData.callData,
            destCall
        );

        _stargateData.callData = newCalldata;

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
}
