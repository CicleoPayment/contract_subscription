// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {IDiamondCut} from "../../Diamond/Interfaces/IDiamondCut.sol";
import {IERC20} from "./../Interfaces/IERC20.sol";
import {IRouter} from "../Interfaces/IOpenOcean.sol";
import {LibPaymentManager} from "../Libraries/LibPaymentManager.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";

library LibPayment {
    function distributeMoney(
        uint256 paymentManagerId,
        uint256 amount
    ) internal {
        LibPaymentManager.PaymentManagerData
            memory paymentInfo = LibPaymentManager.getPaymentManagerInfo(
                paymentManagerId
            );
        require(
            address(paymentInfo.paymentToken) != address(0),
            "Invalid subinfo"
        );

        uint256 taxAmount = (amount * LibAdmin.getTaxPercentage()) / 1000;

        paymentInfo.paymentToken.transfer(
            paymentInfo.treasuryAccount,
            amount - taxAmount
        );
        paymentInfo.paymentToken.transfer(LibAdmin.getTaxAccount(), taxAmount);
    }
}
