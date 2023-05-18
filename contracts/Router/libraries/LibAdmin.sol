// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {CicleoSubscriptionFactory, CicleoSubscriptionSecurity} from "../../SubscriptionFactory.sol";

library LibAdmin {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("com.cicleo.facets.admin");

    struct DiamondStorage {
        CicleoSubscriptionFactory factory;
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function isContractOwner(
        address user,
        uint256 subscriptionManagerId
    ) internal view returns (bool isOwner) {
        isOwner = diamondStorage().factory.verifyIfOwner(
            user,
            subscriptionManagerId
        );
    }

    function enforceIsOwnerOfSubManager(
        uint256 subscriptionManagerId
    ) internal view {
        require(
            isContractOwner(msg.sender, subscriptionManagerId),
            "LibAdmin: Must hold ownerpass for this submanager"
        );
    }

    function ids(uint256 id) internal view returns (address) {
        return diamondStorage().factory.ids(id);
    }

    function security() internal view returns (CicleoSubscriptionSecurity) {
        return diamondStorage().factory.security();
    }

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
