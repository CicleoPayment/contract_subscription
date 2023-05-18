const axios = require("axios");
const ethers = require("ethers");

const endpoint = "https://li.quest/v1/quote/contractCall";

const KLIMA_STAKING_CONTRACT = "0xA2906F6FA75657555dd96fa087647B927D01e4ed";

const STARGATE = [
    {
        inputs: [
            {
                internalType: "contract IStargateRouter",
                name: "_router",
                type: "address",
            },
        ],
        stateMutability: "nonpayable",
        type: "constructor",
    },
    { inputs: [], name: "AlreadyInitialized", type: "error" },
    { inputs: [], name: "ContractCallNotAllowed", type: "error" },
    {
        inputs: [
            { internalType: "uint256", name: "minAmount", type: "uint256" },
            {
                internalType: "uint256",
                name: "receivedAmount",
                type: "uint256",
            },
        ],
        name: "CumulativeSlippageTooHigh",
        type: "error",
    },
    { inputs: [], name: "InformationMismatch", type: "error" },
    {
        inputs: [
            { internalType: "uint256", name: "required", type: "uint256" },
            { internalType: "uint256", name: "balance", type: "uint256" },
        ],
        name: "InsufficientBalance",
        type: "error",
    },
    { inputs: [], name: "InvalidAmount", type: "error" },
    { inputs: [], name: "InvalidConfig", type: "error" },
    { inputs: [], name: "InvalidContract", type: "error" },
    { inputs: [], name: "InvalidReceiver", type: "error" },
    { inputs: [], name: "InvalidStargateRouter", type: "error" },
    { inputs: [], name: "NativeAssetNotSupported", type: "error" },
    { inputs: [], name: "NativeAssetTransferFailed", type: "error" },
    { inputs: [], name: "NoSwapDataProvided", type: "error" },
    { inputs: [], name: "NoSwapFromZeroBalance", type: "error" },
    { inputs: [], name: "NoTransferToNullAddress", type: "error" },
    { inputs: [], name: "NotInitialized", type: "error" },
    { inputs: [], name: "NullAddrIsNotAValidSpender", type: "error" },
    { inputs: [], name: "NullAddrIsNotAnERC20Token", type: "error" },
    { inputs: [], name: "OnlyContractOwner", type: "error" },
    { inputs: [], name: "ReentrancyError", type: "error" },
    { inputs: [], name: "SliceOutOfBounds", type: "error" },
    { inputs: [], name: "SliceOverflow", type: "error" },
    { inputs: [], name: "UnknownLayerZeroChain", type: "error" },
    { inputs: [], name: "UnknownStargatePool", type: "error" },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "uint256",
                name: "chainId",
                type: "uint256",
            },
            {
                indexed: false,
                internalType: "uint16",
                name: "layerZeroChainId",
                type: "uint16",
            },
        ],
        name: "LayerZeroChainIdSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "transactionId",
                type: "bytes32",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receivingAssetId",
                type: "address",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receiver",
                type: "address",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "amount",
                type: "uint256",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "timestamp",
                type: "uint256",
            },
        ],
        name: "LiFiTransferCompleted",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                components: [
                    {
                        internalType: "bytes32",
                        name: "transactionId",
                        type: "bytes32",
                    },
                    { internalType: "string", name: "bridge", type: "string" },
                    {
                        internalType: "string",
                        name: "integrator",
                        type: "string",
                    },
                    {
                        internalType: "address",
                        name: "referrer",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receiver",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmount",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "destinationChainId",
                        type: "uint256",
                    },
                    {
                        internalType: "bool",
                        name: "hasSourceSwaps",
                        type: "bool",
                    },
                    {
                        internalType: "bool",
                        name: "hasDestinationCall",
                        type: "bool",
                    },
                ],
                indexed: false,
                internalType: "struct ILiFi.BridgeData",
                name: "bridgeData",
                type: "tuple",
            },
        ],
        name: "LiFiTransferStarted",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                components: [
                    { internalType: "address", name: "token", type: "address" },
                    { internalType: "uint16", name: "poolId", type: "uint16" },
                ],
                indexed: false,
                internalType: "struct StargateFacet.PoolIdConfig[]",
                name: "poolIdConfigs",
                type: "tuple[]",
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "chainId",
                        type: "uint256",
                    },
                    {
                        internalType: "uint16",
                        name: "layerZeroChainId",
                        type: "uint16",
                    },
                ],
                indexed: false,
                internalType: "struct StargateFacet.ChainIdConfig[]",
                name: "chainIdConfigs",
                type: "tuple[]",
            },
        ],
        name: "StargateInitialized",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "token",
                type: "address",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "poolId",
                type: "uint256",
            },
        ],
        name: "StargatePoolIdSet",
        type: "event",
    },
    {
        inputs: [
            {
                components: [
                    { internalType: "address", name: "token", type: "address" },
                    { internalType: "uint16", name: "poolId", type: "uint16" },
                ],
                internalType: "struct StargateFacet.PoolIdConfig[]",
                name: "poolIdConfigs",
                type: "tuple[]",
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "chainId",
                        type: "uint256",
                    },
                    {
                        internalType: "uint16",
                        name: "layerZeroChainId",
                        type: "uint16",
                    },
                ],
                internalType: "struct StargateFacet.ChainIdConfig[]",
                name: "chainIdConfigs",
                type: "tuple[]",
            },
        ],
        name: "initStargate",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "_destinationChainId",
                type: "uint256",
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "dstPoolId",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmountLD",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "dstGasForCall",
                        type: "uint256",
                    },
                    { internalType: "uint256", name: "lzFee", type: "uint256" },
                    {
                        internalType: "address payable",
                        name: "refundAddress",
                        type: "address",
                    },
                    { internalType: "bytes", name: "callTo", type: "bytes" },
                    { internalType: "bytes", name: "callData", type: "bytes" },
                ],
                internalType: "struct StargateFacet.StargateData",
                name: "_stargateData",
                type: "tuple",
            },
        ],
        name: "quoteLayerZeroFee",
        outputs: [
            { internalType: "uint256", name: "", type: "uint256" },
            { internalType: "uint256", name: "", type: "uint256" },
        ],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "uint256", name: "_chainId", type: "uint256" },
            {
                internalType: "uint16",
                name: "_layerZeroChainId",
                type: "uint16",
            },
        ],
        name: "setLayerZeroChainId",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_token", type: "address" },
            { internalType: "uint16", name: "_poolId", type: "uint16" },
        ],
        name: "setStargatePoolId",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "bytes32",
                        name: "transactionId",
                        type: "bytes32",
                    },
                    { internalType: "string", name: "bridge", type: "string" },
                    {
                        internalType: "string",
                        name: "integrator",
                        type: "string",
                    },
                    {
                        internalType: "address",
                        name: "referrer",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receiver",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmount",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "destinationChainId",
                        type: "uint256",
                    },
                    {
                        internalType: "bool",
                        name: "hasSourceSwaps",
                        type: "bool",
                    },
                    {
                        internalType: "bool",
                        name: "hasDestinationCall",
                        type: "bool",
                    },
                ],
                internalType: "struct ILiFi.BridgeData",
                name: "_bridgeData",
                type: "tuple",
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "dstPoolId",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmountLD",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "dstGasForCall",
                        type: "uint256",
                    },
                    { internalType: "uint256", name: "lzFee", type: "uint256" },
                    {
                        internalType: "address payable",
                        name: "refundAddress",
                        type: "address",
                    },
                    { internalType: "bytes", name: "callTo", type: "bytes" },
                    { internalType: "bytes", name: "callData", type: "bytes" },
                ],
                internalType: "struct StargateFacet.StargateData",
                name: "_stargateData",
                type: "tuple",
            },
        ],
        name: "startBridgeTokensViaStargate",
        outputs: [],
        stateMutability: "payable",
        type: "function",
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: "bytes32",
                        name: "transactionId",
                        type: "bytes32",
                    },
                    { internalType: "string", name: "bridge", type: "string" },
                    {
                        internalType: "string",
                        name: "integrator",
                        type: "string",
                    },
                    {
                        internalType: "address",
                        name: "referrer",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receiver",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmount",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "destinationChainId",
                        type: "uint256",
                    },
                    {
                        internalType: "bool",
                        name: "hasSourceSwaps",
                        type: "bool",
                    },
                    {
                        internalType: "bool",
                        name: "hasDestinationCall",
                        type: "bool",
                    },
                ],
                internalType: "struct ILiFi.BridgeData",
                name: "_bridgeData",
                type: "tuple",
            },
            {
                components: [
                    {
                        internalType: "address",
                        name: "callTo",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "approveTo",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receivingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "fromAmount",
                        type: "uint256",
                    },
                    { internalType: "bytes", name: "callData", type: "bytes" },
                    {
                        internalType: "bool",
                        name: "requiresDeposit",
                        type: "bool",
                    },
                ],
                internalType: "struct LibSwap.SwapData[]",
                name: "_swapData",
                type: "tuple[]",
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "dstPoolId",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmountLD",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "dstGasForCall",
                        type: "uint256",
                    },
                    { internalType: "uint256", name: "lzFee", type: "uint256" },
                    {
                        internalType: "address payable",
                        name: "refundAddress",
                        type: "address",
                    },
                    { internalType: "bytes", name: "callTo", type: "bytes" },
                    { internalType: "bytes", name: "callData", type: "bytes" },
                ],
                internalType: "struct StargateFacet.StargateData",
                name: "_stargateData",
                type: "tuple",
            },
        ],
        name: "swapAndStartBridgeTokensViaStargate",
        outputs: [],
        stateMutability: "payable",
        type: "function",
    },
];
const LIFI = [
    {
        inputs: [
            { internalType: "address", name: "_owner", type: "address" },
            { internalType: "address", name: "_sgRouter", type: "address" },
            { internalType: "address", name: "_executor", type: "address" },
            { internalType: "uint256", name: "_recoverGas", type: "uint256" },
        ],
        stateMutability: "nonpayable",
        type: "constructor",
    },
    {
        inputs: [
            { internalType: "uint256", name: "required", type: "uint256" },
            { internalType: "uint256", name: "balance", type: "uint256" },
        ],
        name: "InsufficientBalance",
        type: "error",
    },
    { inputs: [], name: "InvalidAmount", type: "error" },
    { inputs: [], name: "InvalidStargateRouter", type: "error" },
    { inputs: [], name: "NewOwnerMustNotBeSelf", type: "error" },
    { inputs: [], name: "NoNullOwner", type: "error" },
    { inputs: [], name: "NoPendingOwnershipTransfer", type: "error" },
    { inputs: [], name: "NoTransferToNullAddress", type: "error" },
    { inputs: [], name: "NotPendingOwner", type: "error" },
    { inputs: [], name: "NullAddrIsNotAnERC20Token", type: "error" },
    { inputs: [], name: "ReentrancyError", type: "error" },
    { inputs: [], name: "UnAuthorized", type: "error" },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "executor",
                type: "address",
            },
        ],
        name: "ExecutorSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "transactionId",
                type: "bytes32",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receivingAssetId",
                type: "address",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receiver",
                type: "address",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "amount",
                type: "uint256",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "timestamp",
                type: "uint256",
            },
        ],
        name: "LiFiTransferCompleted",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "bytes32",
                name: "transactionId",
                type: "bytes32",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receivingAssetId",
                type: "address",
            },
            {
                indexed: false,
                internalType: "address",
                name: "receiver",
                type: "address",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "amount",
                type: "uint256",
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "timestamp",
                type: "uint256",
            },
        ],
        name: "LiFiTransferRecovered",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                components: [
                    {
                        internalType: "bytes32",
                        name: "transactionId",
                        type: "bytes32",
                    },
                    { internalType: "string", name: "bridge", type: "string" },
                    {
                        internalType: "string",
                        name: "integrator",
                        type: "string",
                    },
                    {
                        internalType: "address",
                        name: "referrer",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receiver",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "minAmount",
                        type: "uint256",
                    },
                    {
                        internalType: "uint256",
                        name: "destinationChainId",
                        type: "uint256",
                    },
                    {
                        internalType: "bool",
                        name: "hasSourceSwaps",
                        type: "bool",
                    },
                    {
                        internalType: "bool",
                        name: "hasDestinationCall",
                        type: "bool",
                    },
                ],
                indexed: false,
                internalType: "struct ILiFi.BridgeData",
                name: "bridgeData",
                type: "tuple",
            },
        ],
        name: "LiFiTransferStarted",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "_from",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address",
                name: "_to",
                type: "address",
            },
        ],
        name: "OwnershipTransferRequested",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "previousOwner",
                type: "address",
            },
            {
                indexed: true,
                internalType: "address",
                name: "newOwner",
                type: "address",
            },
        ],
        name: "OwnershipTransferred",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "uint256",
                name: "recoverGas",
                type: "uint256",
            },
        ],
        name: "RecoverGasSet",
        type: "event",
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "router",
                type: "address",
            },
        ],
        name: "StargateRouterSet",
        type: "event",
    },
    {
        inputs: [],
        name: "cancelOwnershipTransfer",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "confirmOwnershipTransfer",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "executor",
        outputs: [
            { internalType: "contract IExecutor", name: "", type: "address" },
        ],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "owner",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [],
        name: "pendingOwner",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "assetId", type: "address" },
            {
                internalType: "address payable",
                name: "receiver",
                type: "address",
            },
            { internalType: "uint256", name: "amount", type: "uint256" },
        ],
        name: "pullToken",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "recoverGas",
        outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_executor", type: "address" },
        ],
        name: "setExecutor",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "uint256", name: "_recoverGas", type: "uint256" },
        ],
        name: "setRecoverGas",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_sgRouter", type: "address" },
        ],
        name: "setStargateRouter",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "uint16", name: "", type: "uint16" },
            { internalType: "bytes", name: "", type: "bytes" },
            { internalType: "uint256", name: "", type: "uint256" },
            { internalType: "address", name: "_token", type: "address" },
            { internalType: "uint256", name: "_amountLD", type: "uint256" },
            { internalType: "bytes", name: "_payload", type: "bytes" },
        ],
        name: "sgReceive",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "sgRouter",
        outputs: [{ internalType: "address", name: "", type: "address" }],
        stateMutability: "view",
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "bytes32",
                name: "_transactionId",
                type: "bytes32",
            },
            {
                components: [
                    {
                        internalType: "address",
                        name: "callTo",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "approveTo",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "sendingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "address",
                        name: "receivingAssetId",
                        type: "address",
                    },
                    {
                        internalType: "uint256",
                        name: "fromAmount",
                        type: "uint256",
                    },
                    { internalType: "bytes", name: "callData", type: "bytes" },
                    {
                        internalType: "bool",
                        name: "requiresDeposit",
                        type: "bool",
                    },
                ],
                internalType: "struct LibSwap.SwapData[]",
                name: "_swapData",
                type: "tuple[]",
            },
            { internalType: "address", name: "assetId", type: "address" },
            {
                internalType: "address payable",
                name: "receiver",
                type: "address",
            },
        ],
        name: "swapAndCompleteBridgeTokens",
        outputs: [],
        stateMutability: "payable",
        type: "function",
    },
    {
        inputs: [
            { internalType: "address", name: "_newOwner", type: "address" },
        ],
        name: "transferOwnership",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function",
    },
    { stateMutability: "payable", type: "receive" },
];

// Full ABI on
// https://polygonscan.com/address/0x4D70a031Fc76DA6a9bC0C922101A05FA95c3A227#code
const DIAMOND_BRIDGE_ABI = ["function bridgeSubscription(uint256 subscriptionManagerId, uint8 subscriptionId, address user, uint256 price, bytes memory signature) external"];

const generateKLIMATransaction = async () => {
    const stakeKlimaTx = await new ethers.Contract(
        KLIMA_STAKING_CONTRACT,
        KLIMA_STAKING_ABI
    ).populateTransaction.test(12);
    return stakeKlimaTx;
};

const getQuote = async () => {
    // We would like to stake this amount of KLIMA to get sKLIMA
    const stakeAmount = "1000000";

    const bridgeTx = await new ethers.Contract(
        "0xd54140d51657e59aD74C2F5aE7EF14aFE5990228",
        DIAMOND_BRIDGE_ABI
    ).populateTransaction.test(req.params.submanagerid,req.params.subscriptionid,req.params.user,stakeAmount,"0x0");

    const quoteRequest = {
        fromChain: "POL",
        fromToken: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        fromAddress: "0x631Cf6B04528289A9A015d09D373Ce2CC0e7262D",
        toChain: "FTM",
        toToken: "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
        toAmount: stakeAmount,
        toContractAddress: bridgeTx.to,
        toContractCallData: bridgeTx.data,
        toContractGasLimit: "900000",
        maxPriceImpact: "0.5",
    };

    console.log(stakeKlimaTx.data);

    const response = await axios.post(endpoint, quoteRequest);

    const data = response.data.transactionRequest.data;

    const ifaceStargate = new ethers.utils.Interface(STARGATE);
    const decodedArgsStargate = ifaceStargate.decodeFunctionData(
        data.slice(0, 10),
        data
    );
    const functionNameStargate = ifaceStargate.getFunction(
        data.slice(0, 10)
    ).name;

    console.log(functionNameStargate);

    let _bridgeData
    let _swapData = []
    let _stargateData

    if (functionNameStargate == "startBridgeTokensViaStargate") {
        _bridgeData = decodedArgsStargate[0]
        _stargateData = decodedArgsStargate[1]
    } else if (functionNameStargate == "swapAndStartBridgeTokensViaStargate") {
        _bridgeData = decodedArgsStargate[0]
        _swapData = decodedArgsStargate[1]
        _stargateData = decodedArgsStargate[2]
    }

    console.log(_bridgeData)
    console.log(_swapData)
    console.log(_stargateData)
};

getQuote().then();
