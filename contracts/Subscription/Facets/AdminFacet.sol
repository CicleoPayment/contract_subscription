// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibDiamond} from "../../Diamond/Libraries/LibDiamond.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {IERC173} from "../../Diamond/Interfaces/IERC173.sol";
import {CicleoSubscriptionFactory} from "./../SubscriptionFactory.sol";
import {CicleoSubscriptionManager} from "./../SubscriptionManager.sol";

contract AdminFacet is IERC173 {
    bytes32 internal constant NAMESPACE = keccak256("com.cicleo.facets.admin");

    struct Storage {
        CicleoSubscriptionFactory factory;
        mapping(uint256 => uint8) subscriptionNumber;
    }

    //----Event----------------------------------------------//

    /// @notice Event when an admin change the treasury address
    event TreasuryEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        address newTreasury
    );

    /// @notice Event when an admin change the token address
    event TokenEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed token,
        address newTreasury
    );

    /// @notice Event when an admin change the submanager name
    event NameEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        string newName
    );

    /// @notice Event when a user subscription state is changed (after a payment or via an admin)
    event UserEdited(
        uint256 indexed subscriptionManagerId,
        address indexed user,
        uint8 indexed subscriptionId,
        uint256 endDate
    );

    //----Ownership Part----

    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    //----Admin part----

    /// @notice Function to create a new subscription (admin only)
    /// @param _factory address of the factory
    function setFactory(address _factory) external {
        LibDiamond.enforceIsContractOwner();
        getStorage().factory = CicleoSubscriptionFactory(_factory);
    }

    //----Subscription Manager Ownership Part----

    /// @notice Verify if user have ownerpass for assoicated submanager
    /// @param id Id of the submanager
    function verifyIfOwner(
        address user,
        uint256 id
    ) public view returns (bool) {
        Storage storage s = getStorage();
        return s.factory.verifyIfOwner(user, id);
    }

    //----Subscription Manager Part----//

    /// @notice Function to update a user state (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address to update
    /// @param subscriptionEndDate New subscription end date
    /// @param subscriptionId New subscription id
    function editAccount(
        uint256 subscriptionManagerId,
        address user,
        uint256 subscriptionEndDate,
        uint8 subscriptionId
    ) external {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        subManager.editAccount(user, subscriptionEndDate, subscriptionId);

        emit UserEdited(
            subscriptionManagerId,
            user,
            subscriptionId,
            subscriptionEndDate
        );
    }

    /// @notice Function to set the treasury of the submanager (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param treasury New treasury address
    function setTreasury(
        uint256 subscriptionManagerId,
        address treasury
    ) external {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        subManager.setTreasury(treasury);

        emit TreasuryEdited(subscriptionManagerId, msg.sender, treasury);
    }

    /// @notice Function to set the treasury of the submanager (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param token New token address
    function setToken(uint256 subscriptionManagerId, address token) external {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        subManager.setToken(token);

        emit TokenEdited(subscriptionManagerId, msg.sender, token);
    }

    /// @notice Function to change the name of the submanager (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param name New submanager name
    function setName(
        uint256 subscriptionManagerId,
        string memory name
    ) external {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        subManager.setName(name);

        emit NameEdited(subscriptionManagerId, msg.sender, name);
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
