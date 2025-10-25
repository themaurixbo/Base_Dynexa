// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025

// Importamos la interfaz oficial de ICM/Ictt

interface IICM {
    function sendMessage(
        uint32 dstChainId,
        address dstAddress,
        bytes calldata message
    ) external;

   
}

contract ICM_ICTT_Controller {
    address public icmAddress;         // Dirección del contrato ICM (ICM contract en tu subnet)
    address public owner;              // Admin del contrato

    // Mapeo de mensajes recibidos por chain y remitente
    event MessageSent(uint32 indexed dstChainId, address indexed dstAddress, bytes message);
    event MessageReceived(uint32 indexed srcChainId, address indexed srcAddress, bytes message);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _icmAddress) {
        require(_icmAddress != address(0), "Invalid ICM contract address");
        icmAddress = _icmAddress;
        owner = msg.sender;
    }

    
    function setICMAddress(address _icmAddress) external onlyOwner {
        require(_icmAddress != address(0), "Invalid ICM address");
        icmAddress = _icmAddress;
    }

    // Enviar un mensaje a otra subnet (usando el contrato ICM de Avalanche)
    function sendCrossSubnetMessage(
        uint32 dstChainId,      // ID de la subnet destino (ver docs ICM)
        address dstAddress,     // Contrato destino en la subnet remota
        string calldata text    // Mensaje en texto simple (ejemplo)
    ) external onlyOwner {
        require(icmAddress != address(0), "ICM not set");
        bytes memory payload = abi.encode(text);

        IICM(icmAddress).sendMessage(dstChainId, dstAddress, payload);

        emit MessageSent(dstChainId, dstAddress, payload);
    }

    // Handler de mensajes entrantes (ICM lo invocará)
  
    function handleMessage(
        uint32 srcChainId,
        address srcAddress,
        bytes calldata message
    ) external {
        require(msg.sender == icmAddress, "Only ICM contract can call");
        
        emit MessageReceived(srcChainId, srcAddress, message);
        
    }
}
