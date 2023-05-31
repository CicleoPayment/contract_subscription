// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import {ILiFi, StargateData, AmarokData} from "./../../Interfaces/ILiFi.sol";
import {LibSwap} from "./../../Interfaces/LibSwap.sol";

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

    function startBridgeTokensViaAmarok(
        ILiFi.BridgeData calldata _bridgeData,
        AmarokData calldata _amarokData
    ) external payable;

    function swapAndStartBridgeTokensViaAmarok(
        ILiFi.BridgeData memory _bridgeData,
        LibSwap.SwapData[] calldata _swapData,
        AmarokData calldata _amarokData
    ) external payable;

    function validateDestinationCalldata(
        bytes calldata data,
        bytes calldata dstCalldata
    ) external pure returns (bool isValid);
}
