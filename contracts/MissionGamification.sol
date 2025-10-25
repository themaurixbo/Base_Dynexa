// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// DYNEXA_01_AGU_2025
// Interface mínima del token Dynexa (ERC-20)
interface IDynexasToken {
    function mint(address to, uint256 amount) external;
}

contract MissionGamification {
    address public admin;
    IDynexasToken public dynexasToken;

    struct Mission {
        uint256 id;
        address company;
        string title;
        string description;
        uint256 deadline;
        uint256 tokenRewardAmount;
        bool active;
    }

    struct UserMission {
        bool registered;
        bool completed;
        bool validated;
    }

    uint256 public missionCounter;
    mapping(uint256 => Mission) public missions; // id => Mission
    mapping(uint256 => mapping(address => UserMission)) public userMissions; // missionId => user => UserMission

    event MissionCreated(uint256 indexed missionId, address indexed company, string title);
    event UserRegistered(uint256 indexed missionId, address indexed user);
    event MissionCompleted(uint256 indexed missionId, address indexed user);
    event MissionValidated(uint256 indexed missionId, address indexed user, uint256 reward);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyCompany(uint256 missionId) {
        require(msg.sender == missions[missionId].company, "Only company");
        _;
    }

    constructor(address _dynexasToken) {
        require(_dynexasToken != address(0), "Invalid token address");
        admin = msg.sender;
        dynexasToken = IDynexasToken(_dynexasToken);
    }

    // Crear misión (por empresa)
    function createMission(
        string memory title,
        string memory description,
        uint256 deadline,
        uint256 tokenRewardAmount
    ) external returns (uint256) {
        missionCounter++;
        missions[missionCounter] = Mission({
            id: missionCounter,
            company: msg.sender,
            title: title,
            description: description,
            deadline: deadline,
            tokenRewardAmount: tokenRewardAmount,
            active: true
        });
        emit MissionCreated(missionCounter, msg.sender, title);
        return missionCounter;
    }

    // Usuario se inscribe a la misión
    function registerToMission(uint256 missionId) external {
        require(missions[missionId].active, "Mission not active");
        require(!userMissions[missionId][msg.sender].registered, "Already registered");
        require(block.timestamp < missions[missionId].deadline, "Mission expired");
        userMissions[missionId][msg.sender].registered = true;
        emit UserRegistered(missionId, msg.sender);
    }

    // Usuario marca la misión como completada
    function completeMission(uint256 missionId) external {
        require(userMissions[missionId][msg.sender].registered, "Not registered");
        require(!userMissions[missionId][msg.sender].completed, "Already completed");
        require(block.timestamp < missions[missionId].deadline, "Mission expired");
        userMissions[missionId][msg.sender].completed = true;
        emit MissionCompleted(missionId, msg.sender);
    }

    // Empresa valida y otorga recompensa Dynexas
    function validateAndReward(uint256 missionId, address user) external onlyCompany(missionId) {
        require(userMissions[missionId][user].completed, "User not completed");
        require(!userMissions[missionId][user].validated, "Already validated");
        userMissions[missionId][user].validated = true;

        uint256 reward = missions[missionId].tokenRewardAmount;
        dynexasToken.mint(user, reward);

        emit MissionValidated(missionId, user, reward);
    }

    // Desactivar misión
    function setMissionActive(uint256 missionId, bool active) external onlyCompany(missionId) {
        missions[missionId].active = active;
    }

    // Cambiar admin
    function setAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Zero address");
        admin = newAdmin;
    }
}
