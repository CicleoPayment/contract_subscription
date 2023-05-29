// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {LibDiamond} from "../../Diamond/Libraries/LibDiamond.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {LibPayment} from "../Libraries/LibPayment.sol";
import {LibSubscriptionTypes} from "../Libraries/LibSubscriptionTypes.sol";
import {CicleoSubscriptionFactory, CicleoSubscriptionManager} from "./../SubscriptionFactory.sol";
import {SubscriptionStruct, UserData, SubscriptionManagerStruct, MinimifiedSubscriptionManagerStruct, IOpenOceanCaller, SwapDescription, DynamicSubscriptionData} from "./../Types/CicleoTypes.sol";
import {IERC20} from "../Interfaces/IERC20.sol";

contract PaymentFacet {
    bytes32 internal constant NAMESPACE =
        keccak256("com.cicleo.facets.payment");

    struct Storage {
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
        /// @notice Mapping to store the dynamic subscription info for each user
        mapping(uint256 => mapping(address => DynamicSubscriptionData)) users;
    }

    //-----Event---------------------------------------

    /// @notice Event when a user pays for a subscription (first time or even renewing)
    event PaymentSubscription(
        uint256 indexed subscriptionManagerId,
        address indexed user,
        uint8 indexed subscriptionId,
        uint256 price
    );

    /// @notice Event when a user subscription state is changed (after a payment or via an admin)
    event UserEdited(
        uint256 indexed subscriptionManagerId,
        address indexed user,
        uint8 indexed subscriptionId,
        uint256 endDate
    );

    /// @notice Event when an admin change the tax account
    event ReferralPercentEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        uint16 percent
    );

    /// @notice Event when an user select a token to pay for his subscription (when he pay first time to then store the selected coin)
    event SelectToken(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        address indexed tokenAddress
    );

    /// @notice Event when an user pay for his subscription (when he pay first time  or renew to store on what chain renew)
    event SelectBlockchain(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        uint256 indexed paymentBlockchainId
    );

    //-----------Modifier---------------------------------------------//

    modifier onlyBot() {
        require(msg.sender == getStorage().botAccount, "Only bot");
        _;
    }

    //----Internal function----------------------------------------------//

    /// @notice Function to calculate our tax and redistribute the tokens to the treasury and tax account
    /// @param price Price of the subscription
    /// @param manager Submanager contract
    function redistributeToken(
        uint256 price,
        CicleoSubscriptionManager manager,
        uint256 id,
        address user
    ) internal {
        Storage storage s = getStorage();
        uint256 tax = (price * s.taxPercentage) / 1000;

        IERC20 token = IERC20(manager.tokenAddress());
        address treasury = manager.treasury();

        uint256 toOwner = price - tax;

        (, bool isActive) = manager.getUserSubscriptionStatus(
            s.userReferral[id][user]
        );

        if (
            s.userReferral[id][user] != address(0) &&
            s.referralPercent[id] > 0 &&
            isActive
        ) {
            uint256 referral = (toOwner * s.referralPercent[id]) / 1000;
            toOwner -= referral;
            token.transfer(s.userReferral[id][user], referral);
        }

        token.transfer(treasury, toOwner);
        token.transfer(s.taxAccount, tax);
    }

    /// @notice Internal function to process the payment of the subscription with the submanager token
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    /// @param user User address to pay for the subscription
    /// @param price Price of the subscription (in wei in the submanager token)
    /// @param endDate End date of the subscription (unix timestamp)
    function payFunction(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address user,
        uint256 price,
        uint256 endDate
    ) internal {
        //Avoid verify if subscription is active if it's a dynamic subscription
        if (subscriptionId != 255) {
            require(
                LibSubscriptionTypes
                    .subscriptions(subscriptionManagerId, subscriptionId)
                    .isActive,
                "Subscription is disabled"
            );
        }

        if (
            LibSubscriptionTypes
                .subscriptions(subscriptionManagerId, subscriptionId)
                .price ==
            0 &&
            subscriptionId != 255
        ) {
            endDate = 9999999999;
        }

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        manager.payFunctionWithSubToken(user, subscriptionId, price, endDate);

        redistributeToken(price, manager, subscriptionManagerId, user);

        emit PaymentSubscription(
            subscriptionManagerId,
            user,
            subscriptionId,
            price
        );

        emit UserEdited(subscriptionManagerId, user, subscriptionId, endDate);
    }

    /// @notice Internal function to process the payment of the subscription with swaped token
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    /// @param executor Executor contract (OpenOcean part)
    /// @param desc Swap description (OpenOcean part)
    /// @param calls Calls to execute (OpenOcean part)
    /// @param user User address to pay for the subscription
    /// @param price Price of the subscription (in wei in the submanager token)
    /// @param endDate End date of the subscription (unix timestamp)
    function payFunctionWithSwap(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls,
        address user,
        uint256 price,
        uint256 endDate
    ) internal {
        //Avoid verify if subscription is active if it's a dynamic subscription
        if (subscriptionId != 255) {
            require(
                LibSubscriptionTypes
                    .subscriptions(subscriptionManagerId, subscriptionId)
                    .isActive,
                "Subscription is disabled"
            );
        }

        if (
            LibSubscriptionTypes
                .subscriptions(subscriptionManagerId, subscriptionId)
                .price ==
            0 &&
            subscriptionId != 255
        ) {
            endDate = 9999999999;
        }

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        manager.payFunctionWithSwap(
            user,
            executor,
            desc,
            calls,
            subscriptionId,
            price,
            endDate
        );

        redistributeToken(price, manager, subscriptionManagerId, user);

        emit PaymentSubscription(
            subscriptionManagerId,
            user,
            subscriptionId,
            price
        );

        emit UserEdited(subscriptionManagerId, user, subscriptionId, endDate);
    }

    //-----Change subscription part---------------------------------------------------------

    /// @notice Function to get the price when we change subscription
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address to pay for the subscription
    /// @param newSubscriptionId Id of the new subscription
    function getChangeSubscriptionPrice(
        uint256 subscriptionManagerId,
        address user,
        uint8 newSubscriptionId
    ) external view returns (uint256) {
        return
            LibPayment.getChangeSubscriptionPrice(
                subscriptionManagerId,
                user,
                newSubscriptionId
            );
    }

    /// @notice Function to change subscription type
    /// @param subscriptionManagerId Id of the submanager
    /// @param newSubscriptionId Id of the new subscription
    function changeSubscription(
        uint256 subscriptionManagerId,
        uint8 newSubscriptionId
    ) internal {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (uint256 endDate, uint8 oldSubscriptionId, , , , ) = subManager.users(
            msg.sender
        );

        require(
            endDate > block.timestamp,
            "You don't have an actual subscriptions"
        );

        require(
            oldSubscriptionId != 255,
            "You don't have an actual subscriptions"
        );

        require(
            oldSubscriptionId != newSubscriptionId,
            "You cannot change to the same subscription"
        );

        require(
            LibSubscriptionTypes
                .subscriptions(subscriptionManagerId, newSubscriptionId)
                .isActive,
            "This subscription is not active"
        );

        if (endDate == 9999999999) {
            endDate = block.timestamp + subManager.subscriptionDuration();
        }

        require(
            oldSubscriptionId != 0 && oldSubscriptionId != 255,
            "Invalid Id !"
        );
        require(
            newSubscriptionId != 0 && newSubscriptionId != 255,
            "Invalid Id !"
        );

        uint256 newPrice = LibSubscriptionTypes
            .subscriptions(subscriptionManagerId, newSubscriptionId)
            .price;

        uint256 oldPrice = LibSubscriptionTypes
            .subscriptions(subscriptionManagerId, oldSubscriptionId)
            .price;

        uint256 difference = subManager.changeSubscription(
            msg.sender,
            oldPrice,
            newPrice,
            newSubscriptionId
        );

        emit UserEdited(
            subscriptionManagerId,
            msg.sender,
            newSubscriptionId,
            endDate
        );

        if (difference > 0) {
            redistributeToken(
                difference,
                subManager,
                subscriptionManagerId,
                msg.sender
            );

            emit PaymentSubscription(
                subscriptionManagerId,
                msg.sender,
                newSubscriptionId,
                difference
            );
        }
    }

    /// @notice Function to change subscription type with swap
    /// @param subscriptionManagerId Id of the submanager
    /// @param newSubscriptionId Id of the new subscription
    /// @param executor Executor contract (OpenOcean part)
    /// @param desc Swap description (OpenOcean part)
    /// @param calls Calls to execute (OpenOcean part)
    function changeSubscriptionWithSwap(
        uint256 subscriptionManagerId,
        uint8 newSubscriptionId,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) internal {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (uint256 endDate, uint8 oldSubscriptionId, , , , ) = subManager.users(
            msg.sender
        );

        require(
            endDate > block.timestamp,
            "You don't have an actual subscriptions"
        );

        require(
            oldSubscriptionId != 255,
            "You don't have an actual subscriptions"
        );

        require(
            oldSubscriptionId != newSubscriptionId,
            "You cannot change to the same subscription"
        );

        require(
            LibSubscriptionTypes
                .subscriptions(subscriptionManagerId, newSubscriptionId)
                .isActive,
            "This subscription is not active"
        );

        if (endDate == 9999999999) {
            endDate = block.timestamp + subManager.subscriptionDuration();
        }

        require(
            oldSubscriptionId != 0 && oldSubscriptionId != 255,
            "Invalid Id !"
        );
        require(
            newSubscriptionId != 0 && newSubscriptionId != 255,
            "Invalid Id !"
        );

        uint256 newPrice = LibSubscriptionTypes
            .subscriptions(subscriptionManagerId, newSubscriptionId)
            .price;

        uint256 oldPrice = LibSubscriptionTypes
            .subscriptions(subscriptionManagerId, oldSubscriptionId)
            .price;

        uint256 difference = subManager.changeSubscriptionWithSwap(
            msg.sender,
            oldPrice,
            newPrice,
            newSubscriptionId,
            executor,
            desc,
            calls
        );

        emit UserEdited(
            subscriptionManagerId,
            msg.sender,
            newSubscriptionId,
            endDate
        );

        if (difference > 0) {
            redistributeToken(
                difference,
                subManager,
                subscriptionManagerId,
                msg.sender
            );

            emit PaymentSubscription(
                subscriptionManagerId,
                msg.sender,
                newSubscriptionId,
                difference
            );
        }
    }

    //-------External Subscription functions---------------------------------------------

    /// @notice Function to subscribe to a subscription with the submanager token
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    function subscribe(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address referral
    ) external {
        Storage storage s = getStorage();
        require(
            (subscriptionId > 0 &&
                subscriptionId <=
                LibSubscriptionTypes.subscriptionNumber(
                    subscriptionManagerId
                )) || subscriptionManagerId == 255,
            "Wrong sub type"
        );

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        if (s.userReferral[subscriptionManagerId][msg.sender] == address(0)) {
            s.userReferral[subscriptionManagerId][msg.sender] = referral;
        }

        SubscriptionStruct memory sub = LibSubscriptionTypes.subscriptions(
            subscriptionManagerId,
            subscriptionId
        );

        (uint8 _subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(msg.sender);

        if (_subscriptionId == subscriptionId) {
            require(subscriptionStatus == false, "Already subscribed !");
        }

        if (subscriptionStatus) {
            changeSubscription(subscriptionManagerId, subscriptionId);
        } else {
            payFunction(
                subscriptionManagerId,
                subscriptionId,
                msg.sender,
                sub.price,
                block.timestamp + manager.subscriptionDuration()
            );
        }

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            manager.tokenAddress()
        );

        emit SelectBlockchain(
            subscriptionManagerId,
            msg.sender,
            LibAdmin.getChainID()
        );
    }

    /// @notice Function to subscribe to a subscription with the swapped token
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    /// @param executor Executor contract (OpenOcean part)
    /// @param desc Swap description (OpenOcean part)
    /// @param calls Calls to execute (OpenOcean part)
    function subscribeWithSwap(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address referral,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        Storage storage s = getStorage();
        require(
            (subscriptionId > 0 &&
                subscriptionId <=
                LibSubscriptionTypes.subscriptionNumber(
                    subscriptionManagerId
                )) || subscriptionManagerId == 255,
            "Wrong sub type"
        );

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        if (s.userReferral[subscriptionManagerId][msg.sender] == address(0)) {
            s.userReferral[subscriptionManagerId][msg.sender] = referral;
        }

        SubscriptionStruct memory sub = LibSubscriptionTypes.subscriptions(
            subscriptionManagerId,
            subscriptionId
        );

        (uint8 _subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(msg.sender);

        if (_subscriptionId == subscriptionId) {
            require(subscriptionStatus == false, "Already subscribed !");
        }

        if (subscriptionStatus) {
            changeSubscriptionWithSwap(
                subscriptionManagerId,
                subscriptionId,
                executor,
                desc,
                calls
            );
        } else {
            payFunctionWithSwap(
                subscriptionManagerId,
                subscriptionId,
                executor,
                desc,
                calls,
                msg.sender,
                sub.price,
                block.timestamp + manager.subscriptionDuration()
            );
        }

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            address(desc.srcToken)
        );

        emit SelectBlockchain(
            subscriptionManagerId,
            msg.sender,
            LibAdmin.getChainID()
        );
    }

    //----Dynamic subscriptions functions------------------------------------------

    /// @notice Function to subscribe with a given price and name
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionName Name of the subscription
    /// @param price Price of the subscription
    function subscribeDynamicly(
        uint256 subscriptionManagerId,
        string calldata subscriptionName,
        uint256 price,
        address referral
    ) external {
        Storage storage s = getStorage();
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        s.userReferral[subscriptionManagerId][msg.sender] = referral;

        payFunction(
            subscriptionManagerId,
            255,
            msg.sender,
            price,
            block.timestamp + manager.subscriptionDuration()
        );

        s.users[subscriptionManagerId][msg.sender] = DynamicSubscriptionData(
            subscriptionName,
            price
        );

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            manager.tokenAddress()
        );

        emit SelectBlockchain(
            subscriptionManagerId,
            msg.sender,
            LibAdmin.getChainID()
        );
    }

    /// @notice Function to subscribe with a given price and name with swap
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionName Name of the subscription
    /// @param price Price of the subscription
    /// @param executor Executor contract (OpenOcean part)
    /// @param desc Swap description (OpenOcean part)
    /// @param calls Calls to execute (OpenOcean part)
    function subscribeDynamiclyWithSwap(
        uint256 subscriptionManagerId,
        string calldata subscriptionName,
        uint256 price,
        address referral,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        Storage storage s = getStorage();
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        s.userReferral[subscriptionManagerId][msg.sender] = referral;

        payFunctionWithSwap(
            subscriptionManagerId,
            255,
            executor,
            desc,
            calls,
            msg.sender,
            price,
            block.timestamp + manager.subscriptionDuration()
        );

        s.users[subscriptionManagerId][msg.sender] = DynamicSubscriptionData(
            subscriptionName,
            price
        );

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            address(desc.srcToken)
        );

        emit SelectBlockchain(
            subscriptionManagerId,
            msg.sender,
            LibAdmin.getChainID()
        );
    }

    //------Subscription Renew function--------------------------

    /// @notice Function to renew a subscription with the submanager token (only for the bot)
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address to renew
    function subscriptionRenew(
        uint256 subscriptionManagerId,
        address user
    ) external onlyBot {
        Storage storage s = getStorage();
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (uint8 subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(user);

        uint256 price;

        if (subscriptionId == 0) {
            return;
        } else if (subscriptionId == 255) {
            price = s.users[subscriptionManagerId][user].price;
        } else {
            SubscriptionStruct memory sub = LibSubscriptionTypes.subscriptions(
                subscriptionManagerId,
                subscriptionId
            );

            price = sub.price;
        }

        require(
            subscriptionStatus == false,
            "You can't renew before the end of your subscription"
        );

        payFunction(
            subscriptionManagerId,
            subscriptionId,
            user,
            price,
            block.timestamp + manager.subscriptionDuration()
        );
    }

    /// @notice Function to renew a subscription with the swapped token (only for the bot)
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address to renew
    /// @param executor Executor contract (OpenOcean part)
    /// @param desc Swap description (OpenOcean part)
    /// @param calls Calls to execute (OpenOcean part)
    function subscriptionRenewWithSwap(
        uint256 subscriptionManagerId,
        address user,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external onlyBot {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (uint8 subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(user);

        SubscriptionStruct memory sub = LibSubscriptionTypes.subscriptions(
            subscriptionId,
            subscriptionId
        );

        require(
            subscriptionStatus == false,
            "You can't renew before the end of your subscription"
        );

        payFunctionWithSwap(
            subscriptionManagerId,
            subscriptionId,
            executor,
            desc,
            calls,
            user,
            sub.price,
            block.timestamp + manager.subscriptionDuration()
        );
    }

    //-----Admin Part------------------------------------------------------//

    /// @notice Function to change the tax address
    /// @param _tax Factory address
    function setTax(address _tax) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();
        s.taxAccount = _tax;
    }

    /// @notice Function to change the bot address
    /// @param _botAccount Factory address
    function setBotAccount(address _botAccount) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();
        s.botAccount = _botAccount;
    }

    /// @notice Function to change the tax rate
    /// @param _taxPercentage Tax rate out of 1000
    function setTaxRate(uint16 _taxPercentage) external {
        LibDiamond.enforceIsContractOwner();
        require(_taxPercentage <= 1000, "Tax rate must be less than 1000");
        Storage storage s = getStorage();
        s.taxPercentage = _taxPercentage;
    }

    /// @notice Function to change the LiFi bridge executor
    /// @param _bridgeExecutor Executor address
    function setBridgeExectuor(address _bridgeExecutor) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage s = getStorage();
        s.bridgeExecutor = _bridgeExecutor;
    }

    /// @notice Function to change the referral percent for a submanager
    /// @param subscriptionManagerId Id of the submanager
    /// @param referralTaxPercent Referral percent out of 1000
    function setReferralPercent(
        uint256 subscriptionManagerId,
        uint16 referralTaxPercent
    ) external {
        LibAdmin.enforceIsOwnerOfSubManager(subscriptionManagerId);
        require(referralTaxPercent <= 1000, "You can't go over 1000");

        Storage storage s = getStorage();

        s.referralPercent[subscriptionManagerId] = referralTaxPercent;

        emit ReferralPercentEdited(
            subscriptionManagerId,
            msg.sender,
            referralTaxPercent
        );
    }

    function taxAccount() external view returns (address) {
        return getStorage().taxAccount;
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
