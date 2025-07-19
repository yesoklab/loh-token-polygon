// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title LOH Token - Project LJM Clockwork
 * @dev Lee Jae-myung President 1 hour = 51,169,148 Korean citizens time
 * @notice 디지털 유산 아카이빙 프로젝트의 핵심 토큰
 */
contract LOHToken is ERC20, ERC20Burnable, Pausable, Ownable, ReentrancyGuard {
    
    // ===== 상수 =====
    uint256 public constant TOTAL_SUPPLY = 51169148 * 10**18; // 51,169,148 LOH
    uint256 public constant KOREAN_POPULATION = 51169148; // 대한민국 국민 수
    
    // ===== 스왑 관련 =====
    IERC20 public usdtToken; // USDT 컨트랙트 (Polygon)
    uint256 public lohToUsdtRate = 1000; // 1 USDT = 1000 LOH (초기값)
    bool public swapEnabled = true;
    
    // ===== 스테이킹 관련 =====
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardTime;
        uint256 pendingRewards;
    }
    
    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public stakingRewardRate = 20; // 연 20% APY
    uint256 public minimumStakeAmount = 1000 * 10**18; // 최소 1000 LOH
    bool public stakingEnabled = true;
    
    // ===== 지불 시스템 =====
    struct Payment {
        address payer;
        address recipient;
        uint256 amount;
        string description;
        uint256 timestamp;
        bool completed;
    }
    
    mapping(uint256 => Payment) public payments;
    uint256 public paymentCounter;
    
    // ===== NFT 구매 관련 =====
    mapping(address => bool) public authorizedNFTContracts;
    uint256 public nftPurchaseDiscount = 5; // NFT 구매 시 5% 할인
    
    // ===== 거버넌스 관련 =====
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteWeight;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;
    uint256 public votingPeriod = 7 days;
    uint256 public minimumVotingPower = 10000 * 10**18; // 최소 10,000 LOH
    
    // ===== 이벤트 =====
    event SwapLOHForUSDT(address indexed user, uint256 lohAmount, uint256 usdtAmount);
    event SwapUSDTForLOH(address indexed user, uint256 usdtAmount, uint256 lohAmount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 rewards);
    event PaymentCreated(uint256 indexed paymentId, address indexed payer, address indexed recipient, uint256 amount);
    event PaymentCompleted(uint256 indexed paymentId);
    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event SwapRateUpdated(uint256 newRate);
    
    // ===== 생성자 =====
    constructor(
        address _usdtToken
    ) ERC20("LOH Token - LJM Clockwork", "LOH") {
        _mint(msg.sender, TOTAL_SUPPLY);
        
        if (_usdtToken != address(0)) {
            usdtToken = IERC20(_usdtToken);
        }
    }
    
    // ===== 토큰 정보 =====
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function getProjectInfo() public pure returns (string memory, string memory) {
        return (
            "Project LJM Clockwork - Digital Heritage Archiving",
            "Lee Jae-myung President 1 Hour = 51,169,148 Korean Citizens Time"
        );
    }
    
    function getKoreanMeaning() public pure returns (string memory) {
        return "Lee Jae-myung President 1 hour = 51,169,148 Korean citizens time";
    }
    
    // ===== 스왑 기능 =====
    
    /**
     * @dev LOH → USDT 스왑
     */
    function swapLOHForUSDT(uint256 _lohAmount) external nonReentrant whenNotPaused {
        require(swapEnabled, "Swap is disabled");
        require(_lohAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= _lohAmount, "Insufficient LOH balance");
        require(address(usdtToken) != address(0), "USDT not configured");
        
        uint256 usdtAmount = (_lohAmount * 10**6) / (lohToUsdtRate * 10**18);
        require(usdtToken.balanceOf(address(this)) >= usdtAmount, "Insufficient USDT liquidity");
        
        _transfer(msg.sender, address(this), _lohAmount);
        usdtToken.transfer(msg.sender, usdtAmount);
        
        emit SwapLOHForUSDT(msg.sender, _lohAmount, usdtAmount);
    }
    
    /**
     * @dev USDT → LOH 스왑
     */
    function swapUSDTForLOH(uint256 _usdtAmount) external nonReentrant whenNotPaused {
        require(swapEnabled, "Swap is disabled");
        require(_usdtAmount > 0, "Amount must be greater than 0");
        require(address(usdtToken) != address(0), "USDT not configured");
        require(usdtToken.balanceOf(msg.sender) >= _usdtAmount, "Insufficient USDT balance");
        
        uint256 lohAmount = (_usdtAmount * lohToUsdtRate * 10**18) / 10**6;
        require(balanceOf(address(this)) >= lohAmount, "Insufficient LOH liquidity");
        
        usdtToken.transferFrom(msg.sender, address(this), _usdtAmount);
        _transfer(address(this), msg.sender, lohAmount);
        
        emit SwapUSDTForLOH(msg.sender, _usdtAmount, lohAmount);
    }
    
    // ===== 스테이킹 기능 =====
    
    /**
     * @dev LOH 토큰 스테이킹
     */
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(stakingEnabled, "Staking is disabled");
        require(_amount >= minimumStakeAmount, "Below minimum stake amount");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        StakeInfo storage userStake = stakes[msg.sender];
        
        // 기존 보상 계산
        if (userStake.amount > 0) {
            uint256 pendingRewards = calculateStakingRewards(msg.sender);
            userStake.pendingRewards += pendingRewards;
        }
        
        _transfer(msg.sender, address(this), _amount);
        
        userStake.amount += _amount;
        userStake.startTime = block.timestamp;
        userStake.lastRewardTime = block.timestamp;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }
    
    /**
     * @dev 스테이킹 해제
     */
    function unstake(uint256 _amount) external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "Insufficient staked amount");
        
        uint256 rewards = calculateStakingRewards(msg.sender) + userStake.pendingRewards;
        
        userStake.amount -= _amount;
        userStake.lastRewardTime = block.timestamp;
        userStake.pendingRewards = 0;
        totalStaked -= _amount;
        
        _transfer(address(this), msg.sender, _amount);
        
        if (rewards > 0 && balanceOf(address(this)) >= rewards) {
            _transfer(address(this), msg.sender, rewards);
        }
        
        emit Unstaked(msg.sender, _amount, rewards);
    }
    
    /**
     * @dev 스테이킹 보상 계산
     */
    function calculateStakingRewards(address _user) public view returns (uint256) {
        StakeInfo storage userStake = stakes[_user];
        if (userStake.amount == 0) return 0;
        
        uint256 timeStaked = block.timestamp - userStake.lastRewardTime;
        uint256 rewards = (userStake.amount * stakingRewardRate * timeStaked) / (365 days * 100);
        
        return rewards;
    }
    
    /**
     * @dev 보상만 수령
     */
    function claimRewards() external nonReentrant {
        uint256 rewards = calculateStakingRewards(msg.sender) + stakes[msg.sender].pendingRewards;
        require(rewards > 0, "No rewards to claim");
        require(balanceOf(address(this)) >= rewards, "Insufficient reward pool");
        
        stakes[msg.sender].lastRewardTime = block.timestamp;
        stakes[msg.sender].pendingRewards = 0;
        
        _transfer(address(this), msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    // ===== 지불 시스템 =====
    
    /**
     * @dev 즉시 지불
     */
    function payLOH(address _to, uint256 _amount, string memory _memo) external whenNotPaused {
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be greater than 0");
        
        _transfer(msg.sender, _to, _amount);
        
        paymentCounter++;
        payments[paymentCounter] = Payment({
            payer: msg.sender,
            recipient: _to,
            amount: _amount,
            description: _memo,
            timestamp: block.timestamp,
            completed: true
        });
        
        emit PaymentCompleted(paymentCounter);
    }
    
    /**
     * @dev NFT 구매 (할인 적용)
     */
    function purchaseNFT(address _nftContract, uint256 _amount) external whenNotPaused {
        require(authorizedNFTContracts[_nftContract], "Unauthorized NFT contract");
        require(_amount > 0, "Amount must be greater than 0");
        
        uint256 discountedAmount = (_amount * (100 - nftPurchaseDiscount)) / 100;
        uint256 burnAmount = _amount - discountedAmount;
        
        _transfer(msg.sender, _nftContract, discountedAmount);
        
        if (burnAmount > 0) {
            _burn(msg.sender, burnAmount); // 토큰 소각으로 디플레이션
        }
    }
    
    // ===== 거버넌스 기능 =====
    
    /**
     * @dev 제안 생성
     */
    function createProposal(string memory _description) external {
        require(balanceOf(msg.sender) >= minimumVotingPower, "Insufficient voting power");
        
        proposalCounter++;
        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + votingPeriod;
        
        emit ProposalCreated(proposalCounter, _description);
    }
    
    /**
     * @dev 투표
     */
    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 votingPower = balanceOf(msg.sender) + stakes[msg.sender].amount;
        require(votingPower > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteWeight[msg.sender] = votingPower;
        
        if (_support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        emit Voted(_proposalId, msg.sender, _support, votingPower);
    }
    
    // ===== 관리자 기능 =====
    
    /**
     * @dev USDT 토큰 주소 설정
     */
    function setUSDTToken(address _usdtToken) external onlyOwner {
        usdtToken = IERC20(_usdtToken);
    }
    
    /**
     * @dev 스왑 비율 업데이트
     */
    function updateSwapRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Rate must be greater than 0");
        lohToUsdtRate = _newRate;
        emit SwapRateUpdated(_newRate);
    }
    
    /**
     * @dev NFT 컨트랙트 승인
     */
    function authorizeNFTContract(address _nftContract, bool _authorized) external onlyOwner {
        authorizedNFTContracts[_nftContract] = _authorized;
    }
    
    /**
     * @dev 스왑 활성화/비활성화
     */
    function toggleSwap() external onlyOwner {
        swapEnabled = !swapEnabled;
    }
    
    /**
     * @dev 스테이킹 활성화/비활성화
     */
    function toggleStaking() external onlyOwner {
        stakingEnabled = !stakingEnabled;
    }
    
    /**
     * @dev 스테이킹 보상률 업데이트
     */
    function updateStakingRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 100, "Rate too high"); // 최대 100% APY
        stakingRewardRate = _newRate;
    }
    
    /**
     * @dev 유동성 추가
     */
    function addLiquidity(uint256 _lohAmount, uint256 _usdtAmount) external onlyOwner {
        if (_lohAmount > 0) {
            _transfer(msg.sender, address(this), _lohAmount);
        }
        if (_usdtAmount > 0 && address(usdtToken) != address(0)) {
            usdtToken.transferFrom(msg.sender, address(this), _usdtAmount);
        }
    }
    
    /**
     * @dev 긴급 정지
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 정지 해제
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 긴급 자금 회수
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 lohBalance = balanceOf(address(this));
        if (lohBalance > 0) {
            _transfer(address(this), owner(), lohBalance);
        }
        
        if (address(usdtToken) != address(0)) {
            uint256 usdtBalance = usdtToken.balanceOf(address(this));
            if (usdtBalance > 0) {
                usdtToken.transfer(owner(), usdtBalance);
            }
        }
    }
    
    // ===== 조회 함수 =====
    
    function getSwapRate() external view returns (uint256) {
        return lohToUsdtRate;
    }
    
    function calculateLOHToUSDT(uint256 _lohAmount) external view returns (uint256) {
        return (_lohAmount * 10**6) / (lohToUsdtRate * 10**18);
    }
    
    function calculateUSDTToLOH(uint256 _usdtAmount) external view returns (uint256) {
        return (_usdtAmount * lohToUsdtRate * 10**18) / 10**6;
    }
    
    function getStakeInfo(address _user) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 pendingRewards,
        uint256 calculatedRewards
    ) {
        StakeInfo storage userStake = stakes[_user];
        return (
            userStake.amount,
            userStake.startTime,
            userStake.pendingRewards,
            calculateStakingRewards(_user)
        );
    }
    
    function getProposal(uint256 _proposalId) external view returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.endTime,
            proposal.executed
        );
    }
}
