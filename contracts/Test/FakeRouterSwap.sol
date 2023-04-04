// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import {SwapDescription, IOpenOceanCaller} from "../Types/CicleoTypes.sol";

contract FakeRouterSwap {
    function swap(
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        desc.srcToken.transferFrom(
            desc.srcReceiver,
            address(this),
            desc.amount
        );

        desc.dstToken.transferFrom(
            address(this),
            desc.dstReceiver,
            desc.amount
        );
    }
}
