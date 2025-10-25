// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025
// Interfaz mínima de ERC-20
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;     // DynexasToken only
    function burn(address from, uint256 amount) external;   // DynexasToken only
}

contract SwapDynexas {
    address public admin;
    IERC20 public dynexasToken;
    IERC20 public stableToken; // USDT se depositará

    uint256 public swapRate; // ej: 1 Dynexa = 1 USDT (decimales igualados)

    event Swapped(address indexed user, uint256 dynexasAmount, uint256 stableAmount);
    event LiquidityAdded(address indexed by, uint256 amount);
    event LiquidityRemoved(address indexed by, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address _dynexas, address _stable, uint256 _swapRate) {
        require(_dynexas != address(0) && _stable != address(0), "Zero address");
        require(_swapRate > 0, "Invalid swap rate");
        admin = msg.sender;
        dynexasToken = IERC20(_dynexas);
        stableToken = IERC20(_stable);
        swapRate = _swapRate;
    }

    // El admin puede depositar liquidez (USDT/USDC) al contrato
    function addLiquidity(uint256 amount) external onlyAdmin {
        require(stableToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit LiquidityAdded(msg.sender, amount);
    }

    // El admin puede retirar liquidez (USDT/USDC)
    function removeLiquidity(uint256 amount) external onlyAdmin {
        require(stableToken.balanceOf(address(this)) >= amount, "Not enough liquidity");
        require(stableToken.transfer(msg.sender, amount), "Transfer failed");
        emit LiquidityRemoved(msg.sender, amount);
    }

    // Usuario swapea Dynexas por USDT/USDC (one-way swap, MVP)
    function swapDynexasForStable(uint256 dynexasAmount) external {
        require(dynexasAmount > 0, "Zero amount");
        uint256 stableAmount = dynexasAmount * swapRate;

        // Usuario transfiere Dynexas al contrato (debe haber dado approve)
        require(dynexasToken.transferFrom(msg.sender, address(this), dynexasAmount), "Transfer failed");

        // El contrato quema los Dynexas recibidos (opcional para evitar inflacion)
        dynexasToken.burn(address(this), dynexasAmount);

        // El contrato transfiere USDT/USDC al usuario
        require(stableToken.balanceOf(address(this)) >= stableAmount, "Not enough liquidity");
        require(stableToken.transfer(msg.sender, stableAmount), "Stable transfer failed");

        emit Swapped(msg.sender, dynexasAmount, stableAmount);
    }

    // Cambiar el ratio de swap
    function setSwapRate(uint256 newRate) external onlyAdmin {
        require(newRate > 0, "Invalid rate");
        swapRate = newRate;
    }
}
