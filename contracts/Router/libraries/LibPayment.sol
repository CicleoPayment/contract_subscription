// SPDX-License-Identifier: MITCC BY-NC 2.0
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {CicleoSubscriptionManager} from "../../SubscriptionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibPayment {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("com.cicleo.facets.payment");

    struct DiamondStorage {
        /// @notice Address of the tax account (for cicleo)
        address taxAccount;
        /// @notice Address of the bot account (for cicleo)
        address botAccount;
        /// @notice Address of the LiFi executor
        address bridgeExecutor;
        /// @notice Percentage of tax to apply on each payment
        uint16 taxPercentage;
        /// @notice Mapping to store the user referral data for each submanager
        mapping(uint256 => mapping(address => address)) userReferral;
        /// @notice Mapping to store the referral percent for each submanager
        mapping(uint256 => uint16) referralPercent;
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

    function referralPercent(uint256 id) internal view returns (uint16) {
        return diamondStorage().referralPercent[id];
    }

    function redistributeToken(
        uint256 price,
        CicleoSubscriptionManager manager,
        uint256 id,
        address user
    ) internal {
        uint256 tax = (price * diamondStorage().taxPercentage) / 1000;

        IERC20 token = IERC20(manager.tokenAddress());
        address treasury = manager.treasury();

        uint256 toOwner = price - tax;

        (, bool isActive) = manager.getUserSubscriptionStatus(
            diamondStorage().userReferral[id][user]
        );

        if (
            diamondStorage().userReferral[id][user] != address(0) &&
            diamondStorage().referralPercent[id] > 0 &&
            isActive
        ) {
            uint256 referral = (toOwner *
                diamondStorage().referralPercent[id]) / 1000;
            toOwner -= referral;
            token.transfer(diamondStorage().userReferral[id][user], referral);
        }

        token.transfer(treasury, toOwner);
        token.transfer(diamondStorage().taxAccount, tax);
    }

    function setUserReferral(
        uint256 subManagerId,
        address user,
        address referrer
    ) internal {
        DiamondStorage storage s = diamondStorage();

        s.userReferral[subManagerId][user] = referrer;
    }

    function getBotAccount() internal view returns (address) {
        return diamondStorage().botAccount;
    }
}
