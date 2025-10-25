// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface del DynexasToken (ERC-20)
interface IDynexasToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
}

// Interface del GiftToken (ERC-721)
interface IGiftToken {
    function ownerOf(uint256 tokenId) external view returns (address);
    function burn(uint256 tokenId) external;
}

contract MarketplaceDynexa_B {
    address public admin;
    IDynexasToken public dynexasToken;
    IGiftToken public giftToken;
    uint256 public commissionBasisPoints = 150; // 1.5% comisión (150/10000)
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    struct Product {
        uint256 tokenId;
        uint256 priceDynexas;
        bool active;
        uint256 bonusDynexas; // bonificación extra por compra, en Dynexas
    }

    // Mapping: GiftToken ID => Oferta/Product
    mapping(uint256 => Product) public products;

    event ProductListed(uint256 indexed tokenId, uint256 priceDynexas, uint256 bonusDynexas);
    event ProductDelisted(uint256 indexed tokenId);
    event ProductBought(address indexed buyer, uint256 indexed tokenId, uint256 price, uint256 commission, uint256 bonus);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(giftToken.ownerOf(tokenId) == msg.sender, "Not owner");
        _;
    }

    constructor(address _dynexas, address _giftToken) {
        require(_dynexas != address(0) && _giftToken != address(0), "Zero address");
        admin = msg.sender;
        dynexasToken = IDynexasToken(_dynexas);
        giftToken = IGiftToken(_giftToken);
    }

    // Empresa (dueña del GiftToken) lista el producto
    function listProduct(uint256 tokenId, uint256 priceDynexas, uint256 bonusDynexas) external onlyOwner(tokenId) {
        require(priceDynexas > 0, "Price must be positive");
        products[tokenId] = Product({
            tokenId: tokenId,
            priceDynexas: priceDynexas,
            active: true,
            bonusDynexas: bonusDynexas
        });
        emit ProductListed(tokenId, priceDynexas, bonusDynexas);
    }

    // Empresa puede deslistar el producto
    function delistProduct(uint256 tokenId) external onlyOwner(tokenId) {
        require(products[tokenId].active, "Not listed");
        products[tokenId].active = false;
        emit ProductDelisted(tokenId);
    }

    // Usuario compra el GiftToken y lo canjea (claim)
    function buyAndClaim(uint256 tokenId) external {
        Product memory prod = products[tokenId];
        require(prod.active, "Not listed or already sold");
        address company = giftToken.ownerOf(tokenId);
        require(company != address(0), "Invalid owner");

        // Calcula comisión y monto neto para empresa
        uint256 commission = (prod.priceDynexas * commissionBasisPoints) / BASIS_POINTS_DIVISOR;
        uint256 netAmount = prod.priceDynexas - commission;

        // El usuario paga Dynexas al contrato (debe aprobar antes)
        require(dynexasToken.transferFrom(msg.sender, address(this), prod.priceDynexas), "Pay failed");

        // El contrato transfiere Dynexas netos a la empresa
        require(dynexasToken.transferFrom(address(this), company, netAmount), "To owner failed");

        // El contrato transfiere comisión a la billetera admin/marketplace
        require(dynexasToken.transferFrom(address(this), admin, commission), "To admin failed");

        // Bonificación si corresponde
        if (prod.bonusDynexas > 0) {
            dynexasToken.mint(msg.sender, prod.bonusDynexas);
        }

        // Elimina el NFT (ya fue canjeado)
        giftToken.burn(tokenId);

        // Deslista el producto
        products[tokenId].active = false;

        emit ProductBought(msg.sender, tokenId, prod.priceDynexas, commission, prod.bonusDynexas);
    }

    // Admin puede ajustar la comisión (en basis points)
    function setCommission(uint256 newBps) external onlyAdmin {
        require(newBps <= 1000, "Max 10%");
        commissionBasisPoints = newBps;
    }
}
