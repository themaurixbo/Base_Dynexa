// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

interface IBurnable1155 is IERC1155 {
    function burn(address from, uint256 id, uint256 amount) external;
}

contract Marketplace is Ownable {
    IERC20 public paymentToken;
    IBurnable1155 public giftcardToken;

    uint256 public nextProductId;

    struct Product {
        uint256 id;
        address provider;
        string name;
        uint256 price;
        uint256 giftcardTokenId;
    }

    mapping(uint256 => Product) public catalog;
    mapping(address => uint256[]) public providerProducts;
    mapping(uint256 => address) public giftcardIssuer; // tokenId => provider

    event ProductAdded(uint256 indexed productId, address indexed provider);
    event ProductPurchased(uint256 indexed productId, address indexed buyer);
    event GiftcardRedeemed(address indexed user, uint256 tokenId, uint256 amount);

   constructor(
    address _erc20Token,
    address _erc1155Token,
    address _owner
) Ownable(_owner) {
    paymentToken = IERC20(_erc20Token);
    giftcardToken = IBurnable1155(_erc1155Token);
}


    function addProduct(
        string calldata name,
        uint256 price,
        uint256 giftcardTokenId
    ) external {
        uint256 productId = nextProductId++;

        catalog[productId] = Product({
            id: productId,
            provider: msg.sender,
            name: name,
            price: price,
            giftcardTokenId: giftcardTokenId
        });

        providerProducts[msg.sender].push(productId);
        giftcardIssuer[giftcardTokenId] = msg.sender;

        emit ProductAdded(productId, msg.sender);
    }

    function purchaseProduct(uint256 productId, uint256 amount) external {
        Product memory product = catalog[productId];
        uint256 totalCost = product.price * amount;

        require(
            paymentToken.transferFrom(msg.sender, product.provider, totalCost),
            "Payment failed"
        );

        // Enviar giftcards al comprador
        giftcardToken.safeTransferFrom(product.provider, msg.sender, product.giftcardTokenId, amount, "");

        emit ProductPurchased(productId, msg.sender);
    }

    function redeemGiftcard(address user, uint256 tokenId, uint256 amount) external {
        require(giftcardIssuer[tokenId] == msg.sender, "Only issuer can redeem");
        giftcardToken.burn(user, tokenId, amount);

        emit GiftcardRedeemed(user, tokenId, amount);
    }

    // ERC1155 receiver interface
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
