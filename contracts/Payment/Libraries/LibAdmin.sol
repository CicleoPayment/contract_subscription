// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {IDiamondCut} from "../../Diamond/Interfaces/IDiamondCut.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "../Interfaces/IOpenOcean.sol";
import {LibDiamond} from "../../Diamond/Libraries/LibDiamond.sol";
import {CicleoPaymentSecurity} from "./../Security.sol";

library LibAdmin {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("com.cicleo.facets.admin");

    struct DiamondStorage {
        /// @notice Address of the tax account (for cicleo)
        address taxAccount;
        /// @notice Address of the LiFi executor
        address bridgeExecutor;
        /// @notice Percentage of tax to apply on each payment
        uint16 taxPercentage;
        /// @notice ERC721 Security Contract
        CicleoPaymentSecurity securityContract;
    }

    /// @notice Get chain id of the smartcontract
    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
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

    function getTaxAccount() internal view returns (address) {
        DiamondStorage storage ds = diamondStorage();
        return ds.taxAccount;
    }

    function getBridgeExecutor() internal view returns (address) {
        DiamondStorage storage ds = diamondStorage();
        return ds.bridgeExecutor;
    }

    function getTaxPercentage() internal view returns (uint16) {
        DiamondStorage storage ds = diamondStorage();
        return ds.taxPercentage;
    }

    function getSecurity() internal view returns (CicleoPaymentSecurity) {
        DiamondStorage storage ds = diamondStorage();
        return ds.securityContract;
    }
}
