// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/security/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/utils/Counters.sol";

contract GiftToken is ERC721, AccessControl, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 public constant COMPANY_ROLE = keccak256("COMPANY_ROLE");

    // Expiración opcional para cada token
    mapping(uint256 => uint256) public expirationDate; // tokenId => timestamp

    // URI custom por token
    mapping(uint256 => string) private _tokenURIs;

    // Propietario empresa de cada token
    mapping(uint256 => address) public companyOfToken; // tokenId => empresa

    // Eventos
    event GiftMinted(address indexed to, uint256 indexed tokenId, string tokenURI, uint256 expiration, address indexed company);
    event GiftBurned(address indexed from, uint256 indexed tokenId);

    constructor(address admin_) ERC721("Dynexa GiftToken", "DGT") {
        require(admin_ != address(0), "Admin address cannot be zero");
        _grantRole(ADMIN_ROLE, admin_);
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

    // Permitir a admin agregar empresas minteadoras
    function addCompany(address company) external onlyAdmin {
        require(company != address(0), "Zero address");
        grantRole(COMPANY_ROLE, company);
    }

    function removeCompany(address company) external onlyAdmin {
        revokeRole(COMPANY_ROLE, company);
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    // Mint: solo empresas autorizadas pueden mintear nuevos GiftToken
    function mintGift(
        address to,
        string memory tokenURI_,
        uint256 expirationTimestamp // 0 si no expira
    ) external onlyCompany whenNotPaused returns (uint256) {
        require(to != address(0), "Mint to zero address");
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI_);
        if (expirationTimestamp != 0) {
            expirationDate[newTokenId] = expirationTimestamp;
        }
        // Guardar el "dueño-empresa" del NFT
        companyOfToken[newTokenId] = msg.sender;

        emit GiftMinted(to, newTokenId, tokenURI_, expirationTimestamp, msg.sender);
        return newTokenId;
    }

    // Burn: solo owner o empresa emisora puede canjear el premio
    function burnGift(uint256 tokenId) public whenNotPaused {
        require(
            _isApprovedOrOwner(msg.sender, tokenId) ||
            hasRole(COMPANY_ROLE, msg.sender),
            "Not authorized to burn"
        );
        address owner = ownerOf(tokenId);
        _burn(tokenId);

        emit GiftBurned(owner, tokenId);
    }

    // URI personalizada por token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        return _tokenURIs[tokenId];
    }

    function _setTokenURI(uint256 tokenId, string memory _uri) internal {
        _tokenURIs[tokenId] = _uri;
    }

    // Expiración: función auxiliar
    function isExpired(uint256 tokenId) public view returns (bool) {
        if (expirationDate[tokenId] == 0) return false;
        return block.timestamp > expirationDate[tokenId];
    }

    // Hook de transfer: no permitir transferir tokens expirados
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721) {
        require(!paused(), "GiftToken paused");
        require(!isExpired(tokenId), "GiftToken expired");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // View: obtener empresa original de un NFT
    function companyOf(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "Nonexistent token");
        return companyOfToken[tokenId];
    }

    // Override required by Solidity for multiple inheritance (ERC721 + AccessControl)
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, AccessControl)
    returns (bool)
    {
    return super.supportsInterface(interfaceId);
    }
}



