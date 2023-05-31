// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct StargateData {
    uint256 dstPoolId;
    uint256 minAmountLD;
    uint256 dstGasForCall;
    uint256 lzFee;
    address payable refundAddress;
    bytes callTo;
    bytes callData;
}

/// @param callData The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
/// @param callTo The address of the contract on dest chain that will receive bridged funds and execute data
/// @param relayerFee The amount of relayer fee the tx called xcall with
/// @param slippageTol Max bps of original due to slippage (i.e. would be 9995 to tolerate .05% slippage)
/// @param delegate Destination delegate address
/// @param destChainDomainId The Amarok-specific domainId of the destination chain
struct AmarokData {
    bytes callData;
    address callTo;
    uint256 relayerFee;
    uint256 slippageTol;
    address delegate;
    uint32 destChainDomainId;
}

interface ILiFi {
    /// Structs ///

    struct BridgeData {
        bytes32 transactionId;
        string bridge;
        string integrator;
        address referrer;
        address sendingAssetId;
        address receiver;
        uint256 minAmount;
        uint256 destinationChainId;
        bool hasSourceSwaps;
        bool hasDestinationCall;
    }

    /// Events ///

    event LiFiTransferStarted(ILiFi.BridgeData bridgeData);

    event LiFiTransferCompleted(
        bytes32 indexed transactionId,
        address receivingAssetId,
        address receiver,
        uint256 amount,
        uint256 timestamp
    );

    event LiFiTransferRecovered(
        bytes32 indexed transactionId,
        address receivingAssetId,
        address receiver,
        uint256 amount,
        uint256 timestamp
    );

    event LiFiGenericSwapCompleted(
        bytes32 indexed transactionId,
        string integrator,
        string referrer,
        address receiver,
        address fromAssetId,
        address toAssetId,
        uint256 fromAmount,
        uint256 toAmount
    );

    // Deprecated but kept here to include in ABI to parse historic events
    event LiFiSwappedGeneric(
        bytes32 indexed transactionId,
        string integrator,
        string referrer,
        address fromAssetId,
        address toAssetId,
        uint256 fromAmount,
        uint256 toAmount
    );
}
