// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

library LibSwap {
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }
}
