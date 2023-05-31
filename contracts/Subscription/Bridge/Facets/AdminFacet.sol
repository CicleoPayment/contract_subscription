// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibDiamond} from "../../../Diamond/Libraries/LibDiamond.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {IERC173} from "../../../Diamond/Interfaces/IERC173.sol";
import {CicleoSubscriptionFactory} from "./../../SubscriptionFactory.sol";
import {CicleoSubscriptionManager} from "./../../SubscriptionManager.sol";

contract AdminFacet is IERC173 {
    //----Ownership Part----

    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
