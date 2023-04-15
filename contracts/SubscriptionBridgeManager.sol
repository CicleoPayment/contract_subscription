// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";

/// @title Cicleo Subscription Bridge Manager
/// @author Pol Epie
/// @notice This contract is used to permit the payment via LiFi
contract CicleoSubscriptionBridgeManager {
    /// @notice users Mapping of the networkID to a mapping of the subscription manager id to the user address to the subscription approval
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public usersSubscriptionLimit;

    /// @notice Event when a user change his subscription limit
    event EditSubscriptionLimit(
        address indexed user,
        uint256 indexed chainId,
        uint256 indexed subscriptionManagerId,
        uint256 amountMaxPerPeriod
    );

    /// @notice Edit the subscription limit
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param amountMaxPerPeriod New subscription price limit per period in the submanager token
    function changeSubscriptionLimit(uint256 chainId, uint256 subscriptionManagerId, uint256 amountMaxPerPeriod) external {
        usersSubscriptionLimit[chainId][subscriptionManagerId][msg.sender] = amountMaxPerPeriod;

        emit EditSubscriptionLimit(msg.sender, chainId, subscriptionManagerId, amountMaxPerPeriod);
    }

    /// @notice Function to pay subscription with any coin on another chain
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param price Price of the subscription in the _token
    /// @param _token Token used to pay the subscription
    function payFunctionWithBridge(
        uint256 chainId,
        uint256 subscriptionManagerId,
        uint256 price,
        address _token,
        address payable bridge,
        bytes memory data
    ) external payable {
        //Verify subscription limit
        require(
            usersSubscriptionLimit[chainId][subscriptionManagerId][msg.sender] >= price,
            "You need to approve our contract to spend this amount of tokens"
        );

        IERC20 token = IERC20(_token);

        uint256 balanceBefore = token.balanceOf(address(this));

        token.transferFrom(msg.sender, address(this), price);

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore >= price, "Transfer failed");

        token.approve(bridge, price);

        (bool success, bytes memory data) = bridge.call{value: msg.value}(
            data
        );
    }

    /// @notice Function to renew subscription (called only by bot)
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param price Price of the subscription in the _token
    /// @param _token Token used to pay the subscription
    function renewFunctionWithBridge(
        address user,
        uint256 chainId,
        uint256 subscriptionManagerId,
        uint256 price,
        address _token,
        address payable bridge,
        bytes memory data
    ) external payable {
        //Verify subscription limit
        require(
            usersSubscriptionLimit[chainId][subscriptionManagerId][msg.sender] >= price,
            "You need to approve our contract to spend this amount of tokens"
        );

        IERC20 token = IERC20(_token);

        uint256 balanceBefore = token.balanceOf(address(this));

        token.transferFrom(msg.sender, address(this), price);

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore >= price, "Transfer failed");

        token.approve(bridge, price);

        (bool success, bytes memory data) = bridge.call{value: msg.value}(
            data
        );
    }
}
