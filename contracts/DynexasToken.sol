// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025
// OpenZeppelin imports
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/security/Pausable.sol";

contract DynexasToken is ERC20, AccessControl, Pausable {
    // Roles
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 public constant COMPANY_ROLE = keccak256("COMPANY_ROLE");

    // Events
    event CompanyAdded(address indexed company);
    event CompanyRemoved(address indexed company);

    // Constructor: Asigna el admin
    constructor(address admin_) ERC20("Dynexas Stable Token", "DYNA") {
        require(admin_ != address(0), "Admin address cannot be zero");
        _grantRole(ADMIN_ROLE, admin_);
        // _grantRole(ADMIN_ROLE, msg.sender); // Opcional: también el deployer puede ser admin en test
    }

    // Modifiers
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin");
        _;
    }

    modifier onlyCompany() {
        require(hasRole(COMPANY_ROLE, msg.sender), "Only company");
        _;
    }

    // Admin Functions
    function addCompany(address company) external onlyAdmin {
        require(company != address(0), "Zero address");
        grantRole(COMPANY_ROLE, company);
        emit CompanyAdded(company);
    }

    function removeCompany(address company) external onlyAdmin {
        revokeRole(COMPANY_ROLE, company);
        emit CompanyRemoved(company);
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // Mint/Burn
    function mint(address to, uint256 amount) external onlyCompany whenNotPaused {
        require(to != address(0), "Mint to zero");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyCompany whenNotPaused {
        require(balanceOf(from) >= amount, "Burn exceeds balance");
        _burn(from, amount);
    }

    // Hooks: Override con ambas clases base
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        require(!paused(), "Token is paused");
        super._beforeTokenTransfer(from, to, amount);
    }

    // View Functions
    function isCompany(address account) public view returns (bool) {
        return hasRole(COMPANY_ROLE, account);
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
}
