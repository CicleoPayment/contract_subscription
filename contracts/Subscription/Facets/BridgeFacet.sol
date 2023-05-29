// SPDX-License-Identifier: CC BY-NC 2.0
pragma solidity ^0.8.0;

import {CicleoSubscriptionManager} from "./../SubscriptionManager.sol";
import {LibAdmin} from "../Libraries/LibAdmin.sol";
import {LibPayment} from "../Libraries/LibPayment.sol";
import {LibSubscriptionTypes} from "../Libraries/LibSubscriptionTypes.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "./../Interfaces/IERC20.sol";

struct PaymentParameters {
    uint256 chainId;
    uint256 subscriptionManagerId;
    uint8 subscriptionId;
    uint256 priceInSubToken;
    IERC20 token;
}

contract BridgeFacet {
    bytes32 internal constant NAMESPACE = keccak256("com.cicleo.facets.bridge");

    struct Storage {
        /// @notice Mapping to store the nonce of each tx per user
        mapping(address => uint256) userNonce;
    }

    //-----------Modifier---------------------------------------------//

    modifier onlyBot() {
        require(msg.sender == LibPayment.getBotAccount(), "Only bot");
        _;
    }

    //----Event----------------------------------------------//

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

    //----Internal function with sign part----------------------------------------------//

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function getMessage(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address user,
        uint256 price,
        uint nonce
    ) public view returns (string memory) {
        uint256 chainId = getChainID();
        return
            string(
                abi.encodePacked(
                    "Cicleo Bridged Subscription\n\nChain: ",
                    Strings.toString(chainId),
                    "\nUser: ",
                    Strings.toHexString(uint256(uint160(user)), 20),
                    "\nSubManager: ",
                    Strings.toString(subscriptionManagerId),
                    "\nSubscription: ",
                    Strings.toString(subscriptionId),
                    "\nPrice: ",
                    Strings.toString(price),
                    "\nNonce: ",
                    Strings.toString(nonce)
                )
            ); //, "\nUser: ", user, "\nSubManager: ", Strings.toString(subscriptionManagerId), "\nSubscription: ", Strings.toString(subscriptionId), "\nPrice: ", Strings.toString(price), "\nNonce: ", Strings.toString(nonce))
    }

    function getMessageHash(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address user,
        uint256 price,
        uint nonce
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    getMessage(
                        subscriptionManagerId,
                        subscriptionId,
                        user,
                        price,
                        nonce
                    )
                )
            );
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n000000",
                    _messageHash
                )
            );
    }

    function verify(
        uint256 subscriptionManagerId,
        uint8 subscriptionId,
        address user,
        uint256 price,
        uint nonce,
        bytes memory signature
    ) public view returns (bool) {
        string memory messageHash = getMessage(
            subscriptionManagerId,
            subscriptionId,
            user,
            price,
            nonce
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return verifyString(messageHash, v, r, s) == user;
    }

    // Returns the address that signed a given string message
    function verifyString(
        string memory message,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address signer) {
        // The message header; we will fill in the length next
        string memory header = "\x19Ethereum Signed Message:\n000000";

        uint256 lengthOffset;
        uint256 length;
        assembly {
            // The first word of a string is its length
            length := mload(message)
            // The beginning of the base-10 message length in the prefix
            lengthOffset := add(header, 57)
        }

        // Maximum length we support
        require(length <= 999999);

        // The length of the message's length in base-10
        uint256 lengthLength = 0;

        // The divisor to get the next left-most message length digit
        uint256 divisor = 100000;

        // Move one digit of the message length to the right at a time
        while (divisor != 0) {
            // The place value at the divisor
            uint256 digit = length / divisor;
            if (digit == 0) {
                // Skip leading zeros
                if (lengthLength == 0) {
                    divisor /= 10;
                    continue;
                }
            }

            // Found a non-zero digit or non-leading zero digit
            lengthLength++;

            // Remove this digit from the message length's current value
            length -= digit * divisor;

            // Shift our base-10 divisor over
            divisor /= 10;

            // Convert the digit to its ASCII representation (man ascii)
            digit += 0x30;
            // Move to the next character and write the digit
            lengthOffset++;

            assembly {
                mstore8(lengthOffset, digit)
            }
        }

        // The null string requires exactly 1 zero (unskip 1 leading 0)
        if (lengthLength == 0) {
            lengthLength = 1 + 0x19 + 1;
        } else {
            lengthLength += 1 + 0x19;
        }

        // Truncate the tailing zeros from the header
        assembly {
            mstore(header, lengthLength)
        }

        // Perform the elliptic curve recover operation
        bytes32 check = keccak256(abi.encodePacked(header, message));

        return ecrecover(check, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        // implicitly return (r, s, v)
    }

    //----External function----------------------------------------------//

    /// @notice Function to pay for a subscription with LiFi call
    /// @param user User address to pay for the subscription
    /// @param signature Signature of the caller to verify the caller
    function bridgeSubscribe(
        PaymentParameters memory paymentParams,
        address user,
        address referral,
        bytes memory signature
    ) external {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(paymentParams.subscriptionManagerId)
        );

        require(
            verify(
                paymentParams.subscriptionManagerId,
                paymentParams.subscriptionId,
                user,
                paymentParams.priceInSubToken,
                getStorage().userNonce[user],
                signature
            ),
            "Invalid signature"
        );
        require(paymentParams.subscriptionId != 0, "Invalid Id !");

        if (paymentParams.subscriptionId != 255) {
            require(
                paymentParams.priceInSubToken >=
                    LibPayment.getChangeSubscriptionPrice(
                        paymentParams.subscriptionManagerId,
                        user,
                        paymentParams.subscriptionId
                    ),
                "Wrong price"
            );
        }

        manager.token().transferFrom(
            msg.sender,
            address(this),
            paymentParams.priceInSubToken
        );

        getStorage().userNonce[user]++;

        //Save user referrer
        LibPayment.setUserReferral(
            paymentParams.subscriptionManagerId,
            msg.sender,
            referral
        );

        //Do token distribution
        LibPayment.redistributeToken(
            paymentParams.priceInSubToken,
            manager,
            paymentParams.subscriptionManagerId,
            user
        );

        //End of the subscription
        (uint8 actualSubscription, bool isActive) = manager
            .getUserSubscriptionStatus(user);

        uint256 oldPrice = LibSubscriptionTypes
            .subscriptions(
                paymentParams.subscriptionManagerId,
                actualSubscription
            )
            .price;

        uint256 endDate = manager.bridgeSubscription(
            user,
            paymentParams.subscriptionId,
            isActive == false || oldPrice == 0,
            LibSubscriptionTypes
                .subscriptions(
                    paymentParams.subscriptionManagerId,
                    paymentParams.subscriptionId
                )
                .price
        );

        emit PaymentSubscription(
            paymentParams.subscriptionManagerId,
            user,
            paymentParams.subscriptionId,
            paymentParams.priceInSubToken
        );

        emit UserEdited(
            paymentParams.subscriptionManagerId,
            user,
            paymentParams.subscriptionId,
            endDate
        );

        emit SelectBlockchain(
            paymentParams.subscriptionManagerId,
            msg.sender,
            paymentParams.chainId
        );

        emit SelectToken(
            paymentParams.subscriptionManagerId,
            user,
            address(paymentParams.token)
        );
    }

    function bridgeRenew(
        uint256 subscriptionManagerId,
        address user
    ) external onlyBot {
        CicleoSubscriptionManager manager = CicleoSubscriptionManager(
            LibAdmin.ids(subscriptionManagerId)
        );

        (uint8 subscriptionId, bool isActive) = manager
            .getUserSubscriptionStatus(user);

        uint256 price = LibSubscriptionTypes
            .subscriptions(subscriptionManagerId, subscriptionId)
            .price;

        require(isActive == false, "Sub still running");
        require(subscriptionId != 0, "Invalid Id !");

        manager.token().transferFrom(msg.sender, address(this), price);

        //Do token distribution
        LibPayment.redistributeToken(
            price,
            manager,
            subscriptionManagerId,
            user
        );

        //End of the subscription
        uint256 endDate = block.timestamp + manager.subscriptionDuration();

        manager.editAccount(user, endDate, subscriptionId);

        emit PaymentSubscription(
            subscriptionManagerId,
            user,
            subscriptionId,
            price
        );

        emit UserEdited(subscriptionManagerId, user, subscriptionId, endDate);
    }

    //----Get Functions----------------------------------------------//

    /// @notice Get the nonce of a user
    /// @param user User address to get the nonce
    /// @return nonce of the user
    function getUserNonce(address user) external view returns (uint256) {
        return getStorage().userNonce[user];
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
