// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {IDiamondCut} from "../../Diamond/Interfaces/IDiamondCut.sol";
import {SubscriptionStruct} from "../Types/CicleoTypes.sol";

library LibSubscriptionTypes {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("com.cicleo.facets.subscriptiontypes");

    struct DiamondStorage {
        /// @notice Mapping to store the subscriptions of each submanager
        mapping(uint256 => mapping(uint8 => SubscriptionStruct)) subscriptions;
        /// @notice Mapping to store the current count of subscriptions of each submanager (to calculate next id)
        mapping(uint256 => uint8) subscriptionNumber;
    }

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function subscriptions(
        uint256 subscriptionManagerId,
        uint8 subscriptionId
    ) internal view returns (SubscriptionStruct memory) {
        return
            diamondStorage().subscriptions[subscriptionManagerId][
                subscriptionId
            ];
    }

    function subscriptionNumber(
        uint256 subscriptionManagerId
    ) internal view returns (uint8) {
        return diamondStorage().subscriptionNumber[subscriptionManagerId];
    }
}
