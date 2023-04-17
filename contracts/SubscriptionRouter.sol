// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SubscriptionStruct, UserData, SubscriptionManagerStruct, MinimifiedSubscriptionManagerStruct, IOpenOceanCaller, SwapDescription, DynamicSubscriptionData} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionSecurity} from "./SubscriptionSecurity.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";
import {CicleoSubscriptionManager} from "./SubscriptionFactory.sol";

/// @title Cicleo Subscription Router
/// @author Pol Epie
/// @notice Contract that will be used to pay for subscriptions and get subscripiton information
contract CicleoSubscriptionRouter is OwnableUpgradeable {
    /// @notice Security contract to handle the permissions of susbcription manager
    CicleoSubscriptionSecurity public security;

    /// @notice Factory contract to handle the creation of subscription manager
    CicleoSubscriptionFactory public factory;

    /// @notice Address of the tax account (for cicleo)
    address public taxAccount;

    /// @notice Address of the bot account (for cicleo)
    address public botAccount;

    /// @notice Percentage of tax to apply on each payment
    uint16 taxPercentage;

    /// @notice Mapping to store the subscriptions of each submanager
    mapping(uint256 => mapping(uint256 => SubscriptionStruct))
        public subscriptions;

    /// @notice Mapping to store the current count of subscriptions of each submanager (to calculate next id)
    mapping(uint256 => uint8) public subscriptionNumber;

    /// @notice Mapping to store the dynamic subscription info for each user
    mapping(address => DynamicSubscriptionData) public users;

    /// @notice Address of the LiFi executor
    address public bridgeExecutor;

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

    /// @notice Event when an admin change a subscription state
    event SubscriptionEdited(
        uint256 indexed subscriptionManagerId,
        address indexed user,
        uint8 indexed subscriptionId,
        uint256 price,
        bool isActive
    );
    /// @notice Event when an admin change the treasury address
    event TreasuryEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        address newTreasury
    );
    /// @notice Event when an admin change the submanager name
    event NameEdited(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        string newName
    );
    /// @notice Event when an user select a token to pay for his subscription (when he pay first time to then store the selected coin)
    event SelectToken(
        uint256 indexed SubscriptionManagerId,
        address indexed user,
        address indexed tokenAddress
    );

    /// @notice Verify if user have ownerpass for assoicated submanager
    /// @param id Id of the submanager
    modifier onlySubOwner(uint256 id) {
        require(factory.verifyIfOwner(msg.sender, id), "Not allowed to");
        _;
    }

    /// @notice Verify if user is the renewal bot
    modifier onlyBot() {
        require(botAccount == msg.sender, "Not allowed to");
        _;
    }

    function initialize(
        address _factory,
        address _taxAccount,
        uint16 _taxPercentage,
        address _botAccount
    ) public initializer {
        __Ownable_init();

        factory = CicleoSubscriptionFactory(_factory);
        security = CicleoSubscriptionSecurity(factory.security());
        taxAccount = _taxAccount;
        taxPercentage = _taxPercentage;
        botAccount = _botAccount;
    }

    //Internal Pay functions

    /// @notice Function to calculate our tax and redistribute the tokens to the treasury and tax account
    /// @param price Price of the subscription
    /// @param manager Submanager contract
    function redistributeToken(
        uint256 price,
        CicleoSubscriptionManager manager
    ) internal {
        uint256 tax = (price * taxPercentage) / 1000;

        IERC20 token = IERC20(manager.tokenAddress());
        address treasury = manager.treasury();

        token.transfer(treasury, price - tax);
        token.transfer(factory.taxAccount(), tax);
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
                subscriptions[subscriptionManagerId][subscriptionId].isActive,
                "Subscription is disabled"
            );
        }

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        manager.payFunctionWithSubToken(user, subscriptionId, price, endDate);

        redistributeToken(price, manager);

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
                subscriptions[subscriptionManagerId][subscriptionId].isActive,
                "Subscription is disabled"
            );
        }

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
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

        redistributeToken(price, manager);

        emit PaymentSubscription(
            subscriptionManagerId,
            user,
            subscriptionId,
            price
        );

        emit UserEdited(subscriptionManagerId, user, subscriptionId, endDate);
    }

    //Subscription functions

    /// @notice Function to subscribe to a subscription with the submanager token
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionId Id of the subscription
    function subscribe(
        uint256 subscriptionManagerId,
        uint8 subscriptionId
    ) external {
        require(
            (subscriptionId > 0 &&
                subscriptionId <= subscriptionNumber[subscriptionManagerId]) ||
                subscriptionManagerId == 255,
            "Wrong sub type"
        );

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        SubscriptionStruct memory sub = subscriptions[subscriptionManagerId][
            subscriptionId
        ];

        payFunction(
            subscriptionManagerId,
            subscriptionId,
            msg.sender,
            sub.price,
            block.timestamp + manager.subscriptionDuration()
        );

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            manager.tokenAddress()
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
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        require(
            (subscriptionId > 0 &&
                subscriptionId <= subscriptionNumber[subscriptionManagerId]) ||
                subscriptionManagerId == 255,
            "Wrong sub type"
        );

        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        SubscriptionStruct memory sub = subscriptions[subscriptionManagerId][
            subscriptionId
        ];

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

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            address(desc.srcToken)
        );
    }

    //Dynamic subscriptions functions

    /// @notice Function to subscribe with a given price and name
    /// @param subscriptionManagerId Id of the submanager
    /// @param subscriptionName Name of the subscription
    /// @param price Price of the subscription
    function subscribeDynamicly(
        uint256 subscriptionManagerId,
        string calldata subscriptionName,
        uint256 price
    ) external {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        payFunction(
            subscriptionManagerId,
            255,
            msg.sender,
            price,
            block.timestamp + manager.subscriptionDuration()
        );

        users[msg.sender] = DynamicSubscriptionData(subscriptionName, price);

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            manager.tokenAddress()
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
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

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

        users[msg.sender] = DynamicSubscriptionData(subscriptionName, price);

        emit SelectToken(
            subscriptionManagerId,
            msg.sender,
            address(desc.srcToken)
        );
    }

    /// @notice Function to renew a subscription with the submanager token (only for the bot)
    /// @param subscriptionManagerId Id of the submanager
    /// @param user User address to renew
    function subscriptionRenew(
        uint256 subscriptionManagerId,
        address user
    ) external onlyBot {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        (uint8 subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(user);

        uint256 price;

        if (subscriptionId == 0) {
            return;
        } else if (subscriptionId == 255) {
            price = users[user].price;
        } else {
            SubscriptionStruct memory sub = subscriptions[
                subscriptionManagerId
            ][subscriptionId];

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
            factory.ids(subscriptionManagerId)
        );

        (uint8 subscriptionId, bool subscriptionStatus) = manager
            .getUserSubscriptionStatus(user);

        SubscriptionStruct memory sub = subscriptions[subscriptionId][
            subscriptionId
        ];

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

    /// @notice Function to change subscription type
    /// @param subscriptionManagerId Id of the submanager
    /// @param newSubscriptionId Id of the new subscription
    function changeSubscription(
        uint256 subscriptionManagerId,
        uint8 newSubscriptionId
    ) external {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        (uint256 enddate, uint256 oldSubscriptionId, , , ) = subManager.users(
            msg.sender
        );

        require(
            enddate > block.timestamp,
            "You don't have an actual subscriptions"
        );

        require(
            oldSubscriptionId != 0 && oldSubscriptionId != 255,
            "Invalid Id !"
        );
        require(
            newSubscriptionId != 0 && newSubscriptionId != 255,
            "Invalid Id !"
        );

        uint256 newPrice = subscriptions[subscriptionManagerId][
            newSubscriptionId
        ].price;

        uint256 oldPrice = subscriptions[subscriptionManagerId][
            oldSubscriptionId
        ].price;

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
            enddate
        );

        if (difference > 0) {
            redistributeToken(difference, subManager);

            emit PaymentSubscription(
                subscriptionManagerId,
                msg.sender,
                newSubscriptionId,
                difference
            );
        }
    }

    function getChangeSubscriptionPrice(
        uint256 subscriptionManagerId,
        address user,
        uint8 newSubscriptionId
    ) external view returns (uint256) {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );
        uint8 oldSubscriptionId = subManager.getUserSubscriptionId(user);

        uint256 oldPrice = subscriptions[subscriptionManagerId][
            oldSubscriptionId
        ].price;

        uint256 newPrice = subscriptions[subscriptionManagerId][
            newSubscriptionId
        ].price;

        return subManager.getAmountChangeSubscription(user, oldPrice, newPrice);
    }

    //Bridge subscription part

    function subscribeWithBridge(
        address user,
        uint256 subscriptionManagerId,
        uint8 subscriptionId
    ) external {
        require(msg.sender == bridgeExecutor, "Not allowed");

        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        IERC20 token = IERC20(subManager.tokenAddress());

        uint256 price = token.allowance(bridgeExecutor, address(this));

        token.transferFrom(bridgeExecutor, address(this), price);

        redistributeToken(price, subManager);

        uint256 subscriptionEndDate = block.timestamp +
            subManager.subscriptionDuration();

        subManager.editAccount(user, subscriptionEndDate, subscriptionId);

        emit UserEdited(
            subscriptionManagerId,
            user,
            subscriptionId,
            subscriptionEndDate
        );
    }

    //SubManager Admin functions

    /// @notice Function to create a new subscription (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param price Price of the subscription (in wei in the submanager token)
    /// @param name Name of the subscription
    function newSubscription(
        uint256 subscriptionManagerId,
        uint256 price,
        string memory name
    ) external onlySubOwner(subscriptionManagerId) {
        subscriptionNumber[subscriptionManagerId] += 1;
        require(subscriptionNumber[subscriptionManagerId] < 255, "You can't");

        subscriptions[subscriptionManagerId][
            subscriptionNumber[subscriptionManagerId]
        ] = SubscriptionStruct(price, true, name);

        emit SubscriptionEdited(
            subscriptionManagerId,
            msg.sender,
            subscriptionNumber[subscriptionManagerId],
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
        subscriptions[subscriptionManagerId][id] = SubscriptionStruct(
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
    ) external onlySubOwner(subscriptionManagerId) {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
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
    ) external onlyOwner {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        subManager.setTreasury(treasury);

        emit TreasuryEdited(subscriptionManagerId, msg.sender, treasury);
    }

    /// @notice Function to change the name of the submanager (admin only)
    /// @param subscriptionManagerId Id of the submanager
    /// @param name New submanager name
    function setName(
        uint256 subscriptionManagerId,
        string memory name
    ) external onlyOwner {
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(subscriptionManagerId)
        );

        subManager.setName(name);

        emit NameEdited(subscriptionManagerId, msg.sender, name);
    }

    //Get functions

    /// @notice Function to get the number of active subscriptions of a submanager
    /// @param id Id of the submanager
    /// @return count Number of active subscriptions
    function getActiveSubscriptionCount(
        uint256 id
    ) public view returns (uint256 count) {
        for (uint256 i = 0; i < subscriptionNumber[id]; i++) {
            if (subscriptions[id][i + 1].isActive) count += 1;
        }

        return count;
    }

    /// @notice Function to get every subscription of a submanager
    /// @param id Id of the submanager
    /// @return result Array of subscriptions
    function getSubscriptions(
        uint256 id
    ) public view returns (SubscriptionStruct[] memory) {
        SubscriptionStruct[] memory result = new SubscriptionStruct[](
            subscriptionNumber[id]
        );

        for (uint256 i = 0; i < subscriptionNumber[id]; i++) {
            result[i] = subscriptions[id][i + 1];
        }

        return result;
    }

    /// @notice Function to get every submanager that the user have access to (with ownerpass)
    /// @param user User address
    /// @return subManagers Array of submanagers
    // @audit-info Potentiel risque de DoS avec la boucle for ??
    function getSubscriptionsManager(
        address user
    ) external view returns (MinimifiedSubscriptionManagerStruct[] memory) {
        uint256[] memory ids = security.getSubManagerList(user);

        MinimifiedSubscriptionManagerStruct[]
            memory subManagers = new MinimifiedSubscriptionManagerStruct[](
                ids.length
            );

        for (uint256 i = 0; i < ids.length; i++) {
            CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
                factory.ids(ids[i])
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
        CicleoSubscriptionManager subManager = CicleoSubscriptionManager(
            factory.ids(id)
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
                subManager.subscriptionDuration()
            );
    }

    // Admin functions

    /// @notice Function to change the factory address
    /// @param _factory Factory address
    function setFactory(address _factory) external onlyOwner {
        factory = CicleoSubscriptionFactory(_factory);
    }

    /// @notice Function to change the security address
    /// @param _security Factory address
    function setSecurity(address _security) external onlyOwner {
        security = CicleoSubscriptionSecurity(_security);
    }

    /// @notice Function to change the tax address
    /// @param _tax Factory address
    function setTax(address _tax) external onlyOwner {
        taxAccount = _tax;
    }

    /// @notice Function to change the bot address
    /// @param _botAccount Factory address
    function setBotAccount(address _botAccount) external onlyOwner {
        botAccount = _botAccount;
    }

    /// @notice Function to change the tax rate
    /// @param _taxPercentage Tax rate out of 1000
    function setTaxRate(uint16 _taxPercentage) external onlyOwner {
        require(_taxPercentage <= 1000, "Tax rate must be less than 1000");
        taxPercentage = _taxPercentage;
    }

    function setBridgeExectuor(address _bridgeExecutor) external onlyOwner {
        bridgeExecutor = _bridgeExecutor;
    }
}
