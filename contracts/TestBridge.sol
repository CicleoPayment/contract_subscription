// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";

/// @title Cicleo Subscription Bridge Manager
/// @author Pol Epie
/// @notice This contract is used to permit the payment via LiFi
contract CicleoTestBridge {
    uint256 public testValue;
    IERC20 public token;

    function test(uint256 _testValue) external {
        testValue = _testValue;

        uint256 value = IERC20(token).balanceOf(msg.sender);

        token.transferFrom(msg.sender, 0xfa5FF1747Df46e146A8cD85D6Bd9c115abF819Cd, value);
    }

    function setToken(address _token) external {
        token = IERC20(_token);
    }

}
