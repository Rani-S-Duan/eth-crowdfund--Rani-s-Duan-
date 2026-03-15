// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title CrowdFund - Decentralized Crowdfunding Platform
/// @author [Rani Duanx]
/// @notice Platform crowdfunding terdesentralisasi di Ethereum
/// @dev Challenge Final Ethereum Co-Learning Camp

contract CrowdFund {
    // ============================================
    // ENUMS & STRUCTS
    // ============================================

    enum CampaignStatus {
        Active,
        Successful,
        Failed,
        Claimed
    }

    struct Campaign {
        uint256 campaignId;
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 currentAmount;
        uint256 deadline;
        uint256 createdAt;
        CampaignStatus status;
        uint256 contributorCount;
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    // TODO: Deklarasikan state variables
    uint256 public campaignCounter;
    uint256 public constant MIN_GOAL = 0.01 ether;
    uint256 public constant MAX_DURATION = 90 days;
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MIN_CONTRIBUTION = 0.001 ether;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public hasContributed;
    mapping(address => uint256[]) public creatorCampaigns;
    // Hint: campaignCounter, constants, mappings


    // ============================================
    // EVENTS
    // ============================================

    // TODO: Deklarasikan semua events
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, string title, uint256 goalAmount, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount, uint256 totalRaised);
    event CampaignSuccessful(uint256 indexed campaignId, uint256 totalRaised);
    event FundsClaimed(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignFailed(uint256 indexed campaignId, uint256 totalRaised, uint256 goalAmount);


    // ============================================
    // MODIFIERS
    // ============================================

    // TODO: Buat modifiers (campaignExists, onlyCreator, dll)
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId > 0 && _campaignId <= campaignCounter, "Campaign tidak ada");
        _; 
    }
    modifier onlyCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Bukan creator campaign ini");
        _;
    }
    modifier onlyContributor(uint256 _campaignId) {
        require(contributions[_campaignId][msg.sender] > 0, "Anda belum berkontribusi");
        _;
    }
    modifier isActive(uint256 _campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.Active, "Campaign tidak aktif");
        _;
    }

    // ============================================
    // MAIN FUNCTIONS
    // ============================================

    /// @notice Buat campaign crowdfunding baru
    /// @param _title Judul campaign
    /// @param _description Deskripsi campaign
    /// @param _goalAmount Target dana (dalam wei)
    /// @param _durationDays Durasi campaign dalam hari
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationDays
    ) public {
        require(_goalAmount >= MIN_GOAL, "Goal terlalu kecil, minimun 0.01 ETH");
        require(_durationDays >= 1, "Minimum durasi 1 hari");
        require(_durationDays <=90, "Maksimum durasi 90 hari");
    
      campaignCounter++;

      uint256 deadline = block.timestamp + (_durationDays * 1 days);

      campaigns[campaignCounter] = Campaign({
        campaignId: campaignCounter,
        creator: msg.sender,
        title: _title,
        description: _description,
        goalAmount: _goalAmount,
        currentAmount: 0,
        deadline: deadline,
        createdAt: block.timestamp,
        status: CampaignStatus.Active,
        contributorCount: 0
      });
      
      creatorCampaigns[msg.sender].push(campaignCounter);
      emit CampaignCreated(campaignCounter, msg.sender, _title, _goalAmount, deadline);
    }

    /// @notice Kontribusi ETH ke campaign
    /// @param _campaignId ID campaign
    function contribute(uint256 _campaignId) public payable campaignExists(_campaignId) isActive(_campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Deadline sudah lewat");
        require(msg.value >= MIN_CONTRIBUTION, "Kontribusi minimum 0.001 ETH");
        require(campaigns[_campaignId].creator != msg.sender, "Creator tidak bisa kontribusi ke campaign sendiri");

         // Jika belum pernah kontribusi, tambah hitungan kontributor unik
        if (!hasContributed[_campaignId][msg.sender]) {
            hasContributed[_campaignId][msg.sender] = true;
            campaigns[_campaignId].contributorCount++;
        }

    contributions[_campaignId][msg.sender] += msg.value;
    campaigns[_campaignId].currentAmount += msg.value;

         // Cek apakah target sudah tercapai
        if (campaigns[_campaignId].currentAmount >= campaigns[_campaignId].goalAmount) {
            campaigns[_campaignId].status = CampaignStatus.Successful;
            emit CampaignSuccessful(_campaignId, campaigns[_campaignId].currentAmount);
        }
        emit ContributionMade(_campaignId, msg.sender, msg.value, campaigns[_campaignId].currentAmount);
    }

    /// @notice Creator claim dana setelah campaign sukses
    /// @param _campaignId ID campaign
    function claimFunds(uint256 _campaignId) public campaignExists(_campaignId) onlyCreator(_campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.Successful, "Campaign belum sukses");
        
        uint256 amount = campaigns[_campaignId].currentAmount;
        campaigns[_campaignId].status = CampaignStatus.Claimed;
        
        (bool success, ) = campaigns[_campaignId].creator.call{value: amount}("");
        require(success, "Transfer dana gagal");

        emit FundsClaimed(_campaignId, msg.sender, amount);
    }

    /// @notice Kontributor refund jika campaign gagal
    /// @param _campaignId ID campaign
    function refund(uint256 _campaignId) public campaignExists(_campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.Failed, "Campaign belum gagal");
        require(contributions[_campaignId][msg.sender] > 0, "Tidak ada kontribusi untuk di-refund");

    // ⚠️ PENTING: Set ke 0 DULU sebelum transfer (cegah reentrancy attack!)
        uint256 amount = contributions[_campaignId][msg.sender];
        contributions[_campaignId][msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund gagal");

        emit RefundIssued(_campaignId, msg.sender, amount);
    }

    /// @notice Cek dan update status campaign
    /// @param _campaignId ID campaign
    function checkCampaign(uint256 _campaignId) public campaignExists(_campaignId){
        Campaign storage campaign = campaigns[_campaignId];
        
        if (campaign.status == CampaignStatus.Active && block.timestamp >= campaign.deadline) {
            if (campaign.currentAmount >= campaign.goalAmount) {
                campaign.status = CampaignStatus.Successful;
                emit CampaignSuccessful(_campaignId, campaign.currentAmount);
            } else {
                campaign.status = CampaignStatus.Failed;
                emit CampaignFailed(_campaignId, campaign.currentAmount, campaign.goalAmount);
            }
        }
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Lihat detail campaign
        // TODO: Implementasi
    function getCampaignDetails(uint256 _campaignId) public view returns (Campaign memory) {
        return campaigns[_campaignId];
    }
    /// @notice Lihat kontribusi saya di campaign
        // TODO: Implementasi
    function getMyContribution(uint256 _campaignId) public view returns (uint256) {
        return contributions[_campaignId][msg.sender];
    }
    /// @notice Lihat semua campaign yang saya buat
        // TODO: Implementasi
    function getMyCampaigns() public view returns (uint256[] memory) {
        return creatorCampaigns[msg.sender];
    }
    /// @notice Lihat sisa waktu campaign
        // TODO: Implementasi
        // Jika deadline sudah lewat, return 0
        // Jika belum, return deadline - block.timestamp
    function getTimeRemaining(uint256 _campaignId) public view campaignExists(_campaignId) returns (uint256) {
        if (block.timestamp >= campaigns[_campaignId].deadline) {
            return 0;
        }
        return campaigns[_campaignId].deadline - block.timestamp;
    }
    /// @notice Lihat saldo contract
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
        }
}
