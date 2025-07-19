// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title LOH Token
 * @dev ERC20 Token representing "이재명 대통령 1시간 = 국민 51,169,148명"
 * @author YesOkLab
 * @notice This token represents the concept of Lee Jae-myung's presidency
 * 
 * Project Details:
 * - Total Supply: 51,169,148 LOH tokens
 * - Concept: 1 hour of President Lee Jae-myung = 51,169,148 Korean citizens
 * - Deployed on Polygon network for low transaction fees
 * - Contact: YesOkLab@gmail.com | t.me/YesOkLab_NFT
 * - GitHub: https://github.com/yesoklab/loh-token-polygon
 */
contract LOHToken is ERC20, ERC20Burnable, Ownable, Pausable {
    
    // 프로젝트 상수
    uint256 public constant TOTAL_SUPPLY = 51_169_148 * 10**18; // 51,169,148 LOH
    string private constant PROJECT_CONCEPT = "이재명 대통령 1시간 = 국민 51,169,148명";
    
    // 이벤트
    event ProjectConceptAnnounced(string concept);
    event TokensMinted(address indexed to, uint256 amount);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor() ERC20("LOH Token", "LOH") {
        // 모든 토큰을 배포자에게 발행
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // 프로젝트 컨셉 발표
        emit ProjectConceptAnnounced(PROJECT_CONCEPT);
        emit TokensMinted(msg.sender, TOTAL_SUPPLY);
    }
    
    /**
     * @dev Returns the project concept
     */
    function getProjectConcept() public pure returns (string memory) {
        return PROJECT_CONCEPT;
    }
    
    /**
     * @dev Returns detailed project information
     */
    function getProjectInfo() public pure returns (
        string memory concept,
        uint256 totalSupply,
        string memory contact,
        string memory github
    ) {
        return (
            PROJECT_CONCEPT,
            TOTAL_SUPPLY,
            "YesOkLab@gmail.com | t.me/YesOkLab_NFT",
            "https://github.com/yesoklab/loh-token-polygon"
        );
    }
    
    /**
     * @dev Pauses all token transfers.
     * Requirements:
     * - the caller must be the owner.
     */
    function pause() public onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev Unpauses all token transfers.
     * Requirements:
     * - the caller must be the owner.
     */
    function unpause() public onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
    
    /**
     * @dev Emergency mint function (only owner, only when paused)
     * This function is for emergency purposes only
     */
    function emergencyMint(address to, uint256 amount) public onlyOwner whenPaused {
        require(to != address(0), "LOH: mint to zero address");
        require(amount > 0, "LOH: mint amount must be positive");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @dev Destroys `amount` tokens from the caller.
     * Requirements:
     * - the caller must have at least `amount` tokens.
     */
    function burn(uint256 amount) public override {
        super.burn(amount);
    }
    
    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's allowance.
     * Requirements:
     * - the caller must have allowance for `account`'s tokens of at least `amount`.
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
    }
    
    /**
     * @dev Hook that is called before any transfer of tokens.
     * This includes minting and burning.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    /**
     * @dev Returns the number of decimals used to get its user representation.
     * Override to ensure 18 decimals for compatibility
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    /**
     * @dev Batch transfer function for efficient airdrops
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(recipients.length == amounts.length, "LOH: arrays length mismatch");
        require(recipients.length > 0, "LOH: no recipients");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "LOH: transfer to zero address");
            require(amounts[i] > 0, "LOH: transfer amount must be positive");
            
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function isPaused() public view returns (bool) {
        return paused();
    }
    
    /**
     * @dev Withdraw any ERC20 tokens accidentally sent to this contract
     */
    function withdrawERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "LOH: cannot withdraw LOH tokens");
        IERC20(tokenAddress).transfer(owner(), amount);
    }
    
    /**
     * @dev Withdraw Ether accidentally sent to this contract
     */
    function withdrawEther() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "LOH: no Ether to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "LOH: Ether withdrawal failed");
    }
    
    /**
     * @dev Fallback function to prevent accidental Ether deposits
     */
    receive() external payable {
        revert("LOH: direct Ether deposits not allowed");
    }
    
    /**
     * @dev Returns contract version
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
