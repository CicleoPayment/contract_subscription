// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";

/// @title Cicleo Proxy
/// @author Pol Epie
/// @notice This contract is used to perform multiple delegatecall
contract CicleoProxy {
    error DelegatecallFailed();

    function multiDelegatecall(
        bytes[] memory data,
        address[] calldata target
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint i; i < data.length; i++) {
            (bool ok, bytes memory res) = target[i].delegatecall(data[i]);
            if (!ok) {
                revert DelegatecallFailed();
            }
            results[i] = res;
        }
    }
}