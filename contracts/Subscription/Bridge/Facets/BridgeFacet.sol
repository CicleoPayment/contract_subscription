// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibDiamond} from "../../../Diamond/Libraries/LibDiamond.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {UserBridgeData} from "../Libraries/LibBridge.sol";
import {CicleoSubscriptionFactory} from "./../../SubscriptionFactory.sol";
import {CicleoSubscriptionManager} from "./../../SubscriptionManager.sol";

contract BridgeFacet {
    bytes32 internal constant NAMESPACE = keccak256("com.cicleo.facets.bridge");

    struct Storage {
        mapping(uint256 => mapping(uint256 => mapping(address => UserBridgeData))) users;
    }

    //----Events--------------------------------------------------------//

    /// @notice Event when a user change his subscription limit
    event EditSubscriptionLimit(
        address indexed user,
        uint256 indexed chainId,
        uint256 indexed subscriptionManagerId,
        uint256 amountMaxPerPeriod
    );

    //----External Part----

    /// @notice Edit the subscription limit
    /// @param chainId Chain id where the submanager is
    /// @param subscriptionManagerId Id of the submanager
    /// @param amountMaxPerPeriod New subscription price limit per period in the submanager token
    function changeSubscriptionLimit(
        uint256 chainId,
        uint256 subscriptionManagerId,
        uint256 amountMaxPerPeriod
    ) external {
        getStorage()
        .users[chainId][subscriptionManagerId][msg.sender]
            .subscriptionLimit = amountMaxPerPeriod;

        emit EditSubscriptionLimit(
            msg.sender,
            chainId,
            subscriptionManagerId,
            amountMaxPerPeriod
        );
    }

    //----Diamond storage functions-------------------------------------//

    /// @dev fetch local storage
    function getStorage() private pure returns (Storage storage s) {
        bytes32 namespace = NAMESPACE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := namespace
        }
    }
}
