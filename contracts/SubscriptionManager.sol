// SPDX-License-Identifier: GPL-1.0-or-later
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Interfaces/IERC20.sol";
import {SwapDescription, SubscriptionStruct, UserData, IRouter, IOpenOceanCaller} from "./Types/CicleoTypes.sol";
import {CicleoSubscriptionFactory} from "./SubscriptionFactory.sol";

contract CicleoSubscriptionManager {
    event PaymentSubscription(
        address indexed user,
        uint256 indexed subscrptionType,
        uint256 price
    );
    event UserEdited(
        address indexed user,
        uint256 indexed subscrptionId,
        uint256 endDate
    );
    event Cancel(address indexed user);
    event ApproveSubscription(address indexed user, uint256 amountPerMonth);
    event SubscriptionEdited(
        address indexed user,
        uint256 indexed subscrptionId,
        uint256 price,
        bool isActive
    );
    event TreasuryEdited(address indexed user, address newTreasury);
    event NameEdited(address indexed user, string newName);
    event SelectToken(address indexed user, address indexed tokenAddress);

    mapping(uint256 => SubscriptionStruct) public subscriptions;
    mapping(address => UserData) public users;

    IERC20 public token;
    address public treasury;
    CicleoSubscriptionFactory public factory;
    string public name;
    uint256 public subscriptionNumber;
    IRouter public router;

    modifier onlyOwner() {
        require(
            factory.verifyIfOwner(
                msg.sender,
                factory.subscriptionManagerId(address(this))
            ),
            "Not allowed to"
        );
        _;
    }

    constructor(
        address _factory,
        string memory _name,
        address _token,
        address _treasury
    ) {
        factory = CicleoSubscriptionFactory(_factory);
        name = _name;
        token = IERC20(_token);
        treasury = _treasury;
        router = factory.router();

        emit TreasuryEdited(msg.sender, _treasury);
        emit NameEdited(msg.sender, _name);
    }

    function approveSubscription(uint256 amountMaxPerMonth) external {
        users[msg.sender].approval = amountMaxPerMonth;

        emit ApproveSubscription(msg.sender, amountMaxPerMonth);
    }

    function getSubscripionPrice(
        address user,
        uint256 subscriptionId
    ) public view returns (uint256 price, uint256 endDate) {
        (uint256 actualSubscriptionId, bool active) = getSubscriptionStatus(
            user
        );

        if (active && actualSubscriptionId != 0) {
            if (
                subscriptions[actualSubscriptionId].price <
                subscriptions[subscriptionId].price
            ) {
                uint256 oldSubPricePerDay = subscriptions[actualSubscriptionId]
                    .price / 30;
                uint256 newSubPricePerDay = subscriptions[subscriptionId]
                    .price / 30;

                uint256 daysLeft = (users[user].subscriptionEndDate -
                    block.timestamp) / 1 days;

                return (
                    (daysLeft * newSubPricePerDay) -
                        (daysLeft * oldSubPricePerDay),
                    users[user].subscriptionEndDate
                );
            } else {
                return (0, users[user].subscriptionEndDate);
            }
        }

        return (subscriptions[subscriptionId].price, block.timestamp + 31 days);
    }

    function payFunctionWithSwap(
        uint8 subscrptionType,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls,
        address user,
        uint256 price,
        uint256 endDate
    ) internal {
        require(
            subscrptionType > 0 && subscrptionType <= subscriptionNumber,
            "Wrong sub type"
        );
        require(
            subscriptions[subscrptionType].isActive,
            "Subscription is disabled"
        );

        desc.minReturnAmount = price;

        require(
            users[user].approval >= price,
            "You need to approve our contract to spend this amount of tokens"
        );

        uint256 balanceBefore = token.balanceOf(address(this));
        IERC20(desc.srcToken).transferFrom(user, address(this), desc.amount);

        IERC20(desc.srcToken).approve(address(router), desc.amount);

        //1inch swap
        router.swap(executor, desc, calls);

        //Verify if the token have a transfer fees or if the swap goes okay

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore >= price, "Swap failed");

        uint256 tax = (price * factory.taxPercent()) / 1000;

        token.transfer(treasury, price - tax);
        token.transfer(factory.taxAccount(), balanceAfter - (price - tax));

        users[user].subscriptionEndDate = endDate;
        users[user].subscriptionId = subscrptionType;
        users[user].lastPayment = block.timestamp;
        users[user].canceled = false;

        emit PaymentSubscription(user, subscrptionType, price);
        emit UserEdited(user, subscrptionType, endDate);
    }

    function payFunction(
        address user,
        uint256 subscrptionType,
        uint256 price,
        uint256 endDate
    ) internal {
        require(
            subscrptionType > 0 && subscrptionType <= subscriptionNumber,
            "Wrong sub type"
        );
        require(
            subscriptions[subscrptionType].isActive,
            "Subscription is disabled"
        );

        require(
            users[user].approval >= price,
            "You need to approve our contract to spend this amount of tokens"
        );

        uint256 tax = (price * factory.taxPercent()) / 1000;

        token.transferFrom(user, treasury, price - tax);
        token.transferFrom(user, factory.taxAccount(), tax);

        users[user].subscriptionEndDate = endDate;
        users[user].subscriptionId = subscrptionType;
        users[user].lastPayment = block.timestamp;
        users[user].canceled = false;

        emit PaymentSubscription(user, subscrptionType, price);
        emit UserEdited(user, subscrptionType, endDate);
    }

    function subscriptionRenew(address user) external {
        require(msg.sender == factory.botAddress(), "Not allowed to");

        UserData memory userData = users[user];

        require(
            block.timestamp - userData.lastPayment >= 30 days,
            "You can't renew subscription before 30 days"
        );
        require(userData.subscriptionId != 0, "No subscription for this user");
        require(userData.canceled == false, "Subscription is canceled");

        if (
            token.allowance(user, address(this)) <
            subscriptions[userData.subscriptionId].price ||
            token.balanceOf(user) <
            subscriptions[userData.subscriptionId].price ||
            userData.approval < subscriptions[userData.subscriptionId].price
        ) {
            userData.canceled = true;
        } else {
            payFunction(
                user,
                userData.subscriptionId,
                subscriptions[userData.subscriptionId].price,
                block.timestamp + 31 days
            );
        }
    }

    function subscriptionRenewWithSwap(
        address user,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        require(msg.sender == factory.botAddress(), "Not allowed to");

        UserData memory userData = users[user];

        require(
            block.timestamp - userData.lastPayment >= 30 days,
            "You can't renew subscription before 30 days"
        );
        require(userData.subscriptionId != 0, "No subscription for this user");
        require(userData.canceled == false, "Subscription is canceled");

        if (
            token.allowance(user, address(this)) <
            subscriptions[userData.subscriptionId].price ||
            token.balanceOf(user) <
            subscriptions[userData.subscriptionId].price ||
            userData.approval < subscriptions[userData.subscriptionId].price
        ) {
            userData.canceled = true;
        } else {
            payFunctionWithSwap(
                uint8(userData.subscriptionId),
                executor,
                desc,
                calls,
                msg.sender,
                subscriptions[userData.subscriptionId].price,
                block.timestamp + 31 days
            );
        }
    }

    function payment(uint8 id) external {
        (uint256 price, uint256 endDate) = getSubscripionPrice(msg.sender, id);

        payFunction(msg.sender, id, price, endDate);
        emit SelectToken(msg.sender, address(token));
    }

    function paymentWithSwap(
        uint8 id,
        IOpenOceanCaller executor,
        SwapDescription memory desc,
        IOpenOceanCaller.CallDescription[] calldata calls
    ) external {
        require(id > 0 && id <= subscriptionNumber, "Wrong sub type");
        require(subscriptions[id].isActive, "Subscription is disabled");

        (uint256 price, uint256 endDate) = getSubscripionPrice(msg.sender, id);

        payFunctionWithSwap(
            id,
            executor,
            desc,
            calls,
            msg.sender,
            price,
            endDate
        );
        emit SelectToken(msg.sender, address(desc.srcToken));
    }

    function cancel() external {
        users[msg.sender].canceled = true;

        emit Cancel(msg.sender);
    }

    //Get functions

    function getSubscriptionStatus(
        address user
    ) public view returns (uint256 subscriptionId, bool isActive) {
        UserData memory userData = users[user];
        return (
            userData.subscriptionId,
            subscriptions[userData.subscriptionId].price == 0 ? true : userData.subscriptionEndDate > block.timestamp
        );
    }

    function getSubscriptions()
        external
        view
        returns (SubscriptionStruct[] memory)
    {
        SubscriptionStruct[] memory result = new SubscriptionStruct[](
            subscriptionNumber
        );

        for (uint256 i = 0; i < subscriptionNumber; i++) {
            result[i] = subscriptions[i + 1];
        }

        return result;
    }

    function isFreeSubscription(uint256 id)
        external
        view
        returns (bool isFree)
    {
        return subscriptions[id].price == 0;
    }

    function getActiveSubscriptionCount()
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < subscriptionNumber; i++) {
            if (subscriptions[i + 1].isActive) count += 1;
        }

        return count;
    }

    function tokenAddress() external view returns (address) {
        return address(token);
    }

    function tokenDecimals() external view returns (uint8) {
        return token.decimals();
    }

    function tokenSymbol() external view returns (string memory) {
        return token.symbol();
    }

    //Admin functions

    function newSubscription(
        uint256 _subscriptionPrice,
        string memory _name
    ) external onlyOwner {
        subscriptionNumber += 1;

        subscriptions[subscriptionNumber] = SubscriptionStruct(
            _subscriptionPrice,
            true,
            _name
        );

        emit SubscriptionEdited(
            msg.sender,
            subscriptionNumber,
            _subscriptionPrice,
            true
        );
    }

    function editSubscription(
        uint256 id,
        uint256 _subscriptionPrice,
        string memory _name,
        bool isActive
    ) external onlyOwner {
        subscriptions[id] = SubscriptionStruct(
            _subscriptionPrice,
            isActive,
            _name
        );

        emit SubscriptionEdited(msg.sender, id, _subscriptionPrice, isActive);
    }

    function setName(string memory _name) external onlyOwner {
        name = _name;

        emit NameEdited(msg.sender, _name);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;

        emit TreasuryEdited(msg.sender, _treasury);
    }

    function editAccount(
        address user,
        uint256 subscriptionEndDate,
        uint256 subscriptionId
    ) external onlyOwner {
        UserData memory _user = users[user];

        users[user] = UserData(
            subscriptionEndDate,
            subscriptionId,
            _user.approval,
            _user.lastPayment,
            _user.canceled
        );

        emit UserEdited(user, subscriptionId, subscriptionEndDate);
    }

    function deleteSubManager() external onlyOwner {
        factory.security().deleteSubManager();
        selfdestruct(payable(factory.taxAccount()));
    }
}
