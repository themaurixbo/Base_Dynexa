// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/security/Pausable.sol";

contract CompanyRegistry is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    struct Company {
        string name;
        string metadata; // JSON string (NIT, dirección, etc.)
        bool isActive;
        address wallet;
        string cmiId;      // <-- ID único de CMI/ICM/Subnet Dynexa
        uint256 createdAt;
    }

    mapping(address => Company) public companies;
    address[] public companyList;

    event CompanyRegistered(address indexed company, string name, string metadata, string cmiId);
    event CompanyUpdated(address indexed company, string name, string metadata, bool isActive, string cmiId);
    event CompanyStatusChanged(address indexed company, bool isActive);
    event CompanyCmiIdUpdated(address indexed company, string cmiId);

    constructor(address admin_) {
        require(admin_ != address(0), "Admin address cannot be zero");
        _grantRole(ADMIN_ROLE, admin_);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin");
        _;
    }

    // Registrar nueva empresa
    function registerCompany(
        address wallet,
        string memory name,
        string memory metadata,
        string memory cmiId
    ) external onlyAdmin whenNotPaused {
        require(wallet != address(0), "Zero address");
        require(!companies[wallet].isActive, "Company already active");

        companies[wallet] = Company({
            name: name,
            metadata: metadata,
            isActive: true,
            wallet: wallet,
            cmiId: cmiId,
            createdAt: block.timestamp
        });
        companyList.push(wallet);

        emit CompanyRegistered(wallet, name, metadata, cmiId);
    }

    // Editar empresa
    function updateCompany(
        address wallet,
        string memory name,
        string memory metadata,
        string memory cmiId
    ) external onlyAdmin whenNotPaused {
        require(companies[wallet].isActive, "Company not active");
        companies[wallet].name = name;
        companies[wallet].metadata = metadata;
        companies[wallet].cmiId = cmiId;
        emit CompanyUpdated(wallet, name, metadata, companies[wallet].isActive, cmiId);
    }

    // Cambiar sólo el cmiId
    function updateCmiId(address wallet, string memory cmiId) external onlyAdmin {
        require(companies[wallet].isActive, "Company not active");
        companies[wallet].cmiId = cmiId;
        emit CompanyCmiIdUpdated(wallet, cmiId);
    }

    // Desactivar o activar empresa (no borrar para trazabilidad)
    function setCompanyStatus(address wallet, bool active) external onlyAdmin {
        require(companies[wallet].wallet != address(0), "Company not found");
        companies[wallet].isActive = active;
        emit CompanyStatusChanged(wallet, active);
    }

    // Ver si una address es empresa activa
    function isCompany(address wallet) public view returns (bool) {
        return companies[wallet].isActive;
    }

    // Obtener CMI ID por wallet
    function getCmiId(address wallet) public view returns (string memory) {
        require(companies[wallet].wallet != address(0), "Company not found");
        return companies[wallet].cmiId;
    }

    // Obtener lista de empresas (direcciones)
    function getAllCompanies() external view returns (address[] memory) {
        return companyList;
    }

    // Pausa global de gestión
    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }
}
