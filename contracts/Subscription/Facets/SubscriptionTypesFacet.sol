// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {SubscriptionStruct, MinimifiedSubscriptionManagerStruct, SubscriptionManagerStruct} from "../Types/CicleoTypes.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {LibPayment} from "../Libraries/LibPayment.sol";
import {CicleoSubscriptionManager} from "../SubscriptionManager.sol";
import {CicleoSubscriptionSecurity} from "../SubscriptionSecurity.sol";

contract SubscriptionTypesFacet {
    bytes32 internal constant NAMESPACE =
        keccak256("com.cicleo.facets.subscriptiontypes");

    struct Storage {
        /// @notice Mapping to store the subscriptions of each submanager
        mapping(uint256 => mapping(uint256 => SubscriptionStruct)) subscriptions;
        /// @notice Mapping to store the current count of subscriptions of each submanager (to calculate next id)
        mapping(uint256 => uint8) subscriptionNumber;
    }

    /// @notice Event when an admin change a subscription state
    event SubscriptionEdited(
        uint256 indexed subscriptionManagerId,
        address indexed user,
        uint8 indexed subscriptionId,
        uint256 price,
        bool isActive
    );

    modifier onlySubOwner(uint256 subscriptionManagerId) {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        _;
    }

    //----External function----------------------------------------------//

    /// @notice Function to create a new subscription (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param price Price of the subscription (in wei in the submanager token)
    /// @param name Name of the subscription
    function newSubscription(
        uint256 subscriptionManagerId,
        uint256 price,
        string memory name
    ) external onlySubOwner(subscriptionManagerId) {
        Storage storage s = getStorage();

        s.subscriptionNumber[subscriptionManagerId] += 1;
        require(s.subscriptionNumber[subscriptionManagerId] < 255, "You can't");

        s.subscriptions[subscriptionManagerId][
            s.subscriptionNumber[subscriptionManagerId]
        ] = SubscriptionStruct(price, true, name);

        emit SubscriptionEdited(
            subscriptionManagerId,
            msg.sender,
            s.subscriptionNumber[subscriptionManagerId],
            price,
            true
        );
    }

    /// @notice Function to edit a existing subscription (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param id Id of the subscription
    /// @param price Price of the subscription (in wei in the submanager token)
    /// @param name Name of the subscription
    function editSubscription(
        uint256 subscriptionManagerId,
        uint8 id,
        uint256 price,
        string memory name,
        bool isActive
    ) external onlySubOwner(subscriptionManagerId) {
        require(id != 0 && id != 255, "You can't");
        Storage storage s = getStorage();

        s.subscriptions[subscriptionManagerId][id] = SubscriptionStruct(
            price,
            isActive,
            name
        );

        emit SubscriptionEdited(
            subscriptionManagerId,
            msg.sender,
            id,
            price,
            isActive
        );
    }

    //----Get functions--------------------------------------------------//

    /// @notice Get the array of subscription of a submanager
    /// @param id Id of the submanager
    /// @return Array of subscription
    function getSubscriptions(
        uint256 id
    ) public view returns (SubscriptionStruct[] memory) {
        Storage storage s = getStorage();

        SubscriptionStruct[] memory result = new SubscriptionStruct[](
            s.subscriptionNumber[id]
        );

        for (uint256 i = 0; i < s.subscriptionNumber[id]; i++) {
            result[i] = s.subscriptions[id][i + 1];
        }

        return result;
    }

    /// @notice Function to get the number of active subscriptions of a submanager
    /// @param id Id of the submanager
    /// @return count Number of active subscriptions
    function getActiveSubscriptionCount(
        uint256 id
    ) public view returns (uint256 count) {
        Storage storage s = getStorage();

        for (uint256 i = 0; i < s.subscriptionNumber[id]; i++) {
            if (s.subscriptions[id][i + 1].isActive) count += 1;
        }

        return count;
    }

    /// @notice Function to get the subscription status (subscriptionID and if the subscription is still active)
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address
    function getUserSubscriptionStatus(
        uint256 subscriptionManagerId,
        address user
    ) public view returns (uint8 subscriptionId, bool isActive) {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (subscriptionId, isActive) = subManager.getUserSubscriptionStatus(user);
    }

    /// @notice Function to get every submanager that the user have access to (with ownerpass)
    /// @param user User address
    /// @return subManagers Array of submanagers
    // @audit-info Potentiel risque de DoS avec la boucle for ??
    function getSubscriptionsManager(
        address user
    ) external view returns (MinimifiedSubscriptionManagerStruct[] memory) {
        CicleoSubscriptionSecurity security = LibAdmin.security();

        uint256[] memory ids = security.getSubManagerList(user);

        MinimifiedSubscriptionManagerStruct[]
            memory subManagers = new MinimifiedSubscriptionManagerStruct[](
                ids.length
            );

        for (uint256 i = 0; i < ids.length; i++) {
            CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
                LibAdmin.ids(ids[i])
            );

            subManagers[i] = MinimifiedSubscriptionManagerStruct(
                ids[i],
                subManager.name(),
                subManager.tokenSymbol(),
                getActiveSubscriptionCount(ids[i])
            );
        }

        return subManagers;
    }

    /// @notice Function to get submanager info by id
    /// @param id User address
    /// @return subManagers struct
    function getSubscriptionManager(
        uint256 id
    ) external view returns (SubscriptionManagerStruct memory) {
        CicleoSubscriptionSecurity security = LibAdmin.security();
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(id)
        );

        return
            SubscriptionManagerStruct(
                id,
                address(subManager),
                subManager.name(),
                subManager.tokenAddress(),
                subManager.tokenSymbol(),
                subManager.tokenDecimals(),
                getActiveSubscriptionCount(id),
                subManager.treasury(),
                getSubscriptions(id),
                security.getOwnersBySubmanagerId(id),
                subManager.subscriptionDuration(),
                LibPayment.referralPercent(id)
            );
    }

    function subscriptions(
        uint256 subscriptionManagerId,
        uint8 subscriptionId
    ) external view returns (SubscriptionStruct memory) {
        Storage storage s = getStorage();
        return s.subscriptions[subscriptionManagerId][subscriptionId];
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
