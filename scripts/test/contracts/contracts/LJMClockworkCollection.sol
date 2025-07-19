// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title LJM Clockwork Collection
 * @dev ERC721 NFT Collection representing Lee Jae-myung Clockwork artworks
 * @author YesOkLab
 * @notice This NFT collection represents precision and dedication like clockwork
 * 
 * Collection Details:
 * - Maximum Supply: 5,800 NFTs
 * - Theme: Lee Jae-myung Clockwork - Precision in Leadership
 * - Each NFT represents a moment of dedicated service
 * - Deployed on Polygon network for accessibility
 * - Contact: YesOkLab@gmail.com | t.me/YesOkLab_NFT
 * - GitHub: https://github.com/yesoklab/loh-token-polygon
 */
contract LJMClockworkCollections is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    Ownable, 
    Pausable, 
    ReentrancyGuard 
{
    using Counters for Counters.Counter;
    
    // 카운터
    Counters.Counter private _tokenIdCounter;
    
    // 컬렉션 상수
    uint256 public constant MAX_SUPPLY = 5800; // 최대 5,800개 NFT
    uint256 public constant MINT_PRICE = 0.001 ether; // 민팅 가격 (Polygon MATIC)
    uint256 public constant MAX_MINT_PER_TRANSACTION = 10; // 거래당 최대 민팅 수
    uint256 public constant MAX_MINT_PER_WALLET = 50; // 지갑당 최대 민팅 수
    
    // 컬렉션 정보
    string private constant COLLECTION_CONCEPT = "LJM Clockwork - 시계처럼 정확한 리더십";
    string private _baseTokenURI;
    string private _contractURI;
    
    // 매핑
    mapping(address => uint256) public mintedByWallet; // 지갑별 민팅 수량
    mapping(uint256 => string) private _tokenURIs; // 토큰별 메타데이터 URI
    
    // 민팅 상태
    bool public publicSaleActive = false;
    bool public whitelistSaleActive = false;
    mapping(address => bool) public whitelist; // 화이트리스트
    
    // 이벤트
    event CollectionConceptAnnounced(string concept);
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event PublicSaleToggled(bool active);
    event WhitelistSaleToggled(bool active);
    event WhitelistAdded(address indexed account);
    event WhitelistRemoved(address indexed account);
    event BaseURIUpdated(string newBaseURI);
    event Withdrawal(address indexed to, uint256 amount);
    
    /**
     * @dev Constructor
     */
    constructor() ERC721("LJM Clockwork Collections", "LJMCC") {
        // 첫 번째 토큰 ID를 1부터 시작
        _tokenIdCounter.increment();
        
        // 컬렉션 컨셉 발표
        emit CollectionConceptAnnounced(COLLECTION_CONCEPT);
    }
    
    /**
     * @dev Returns the collection concept
     */
    function getCollectionConcept() public pure returns (string memory) {
        return COLLECTION_CONCEPT;
    }
    
    /**
     * @dev Returns detailed collection information
     */
    function getCollectionInfo() public view returns (
        string memory concept,
        uint256 maxSupply,
        uint256 currentSupply,
        uint256 mintPrice,
        string memory contact,
        string memory github
    ) {
        return (
            COLLECTION_CONCEPT,
            MAX_SUPPLY,
            totalSupply(),
            MINT_PRICE,
            "YesOkLab@gmail.com | t.me/YesOkLab_NFT",
            "https://github.com/yesoklab/loh-token-polygon"
        );
    }
    
    /**
     * @dev Public mint function
     */
    function publicMint(uint256 quantity) external payable nonReentrant whenNotPaused {
        require(publicSaleActive, "LJMCC: Public sale not active");
        require(quantity > 0 && quantity <= MAX_MINT_PER_TRANSACTION, "LJMCC: Invalid quantity");
        require(totalSupply() + quantity <= MAX_SUPPLY, "LJMCC: Exceeds max supply");
        require(mintedByWallet[msg.sender] + quantity <= MAX_MINT_PER_WALLET, "LJMCC: Exceeds wallet limit");
        require(msg.value >= MINT_PRICE * quantity, "LJMCC: Insufficient payment");
        
        _mintTokens(msg.sender, quantity);
    }
    
    /**
     * @dev Whitelist mint function
     */
    function whitelistMint(uint256 quantity) external payable nonReentrant whenNotPaused {
        require(whitelistSaleActive, "LJMCC: Whitelist sale not active");
        require(whitelist[msg.sender], "LJMCC: Not whitelisted");
        require(quantity > 0 && quantity <= MAX_MINT_PER_TRANSACTION, "LJMCC: Invalid quantity");
        require(totalSupply() + quantity <= MAX_SUPPLY, "LJMCC: Exceeds max supply");
        require(mintedByWallet[msg.sender] + quantity <= MAX_MINT_PER_WALLET, "LJMCC: Exceeds wallet limit");
        require(msg.value >= MINT_PRICE * quantity, "LJMCC: Insufficient payment");
        
        _mintTokens(msg.sender, quantity);
    }
    
    /**
     * @dev Owner mint function (for giveaways, team, etc.)
     */
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0), "LJMCC: Mint to zero address");
        require(quantity > 0, "LJMCC: Invalid quantity");
        require(totalSupply() + quantity <= MAX_SUPPLY, "LJMCC: Exceeds max supply");
        
        _mintTokens(to, quantity);
    }
    
    /**
     * @dev Internal mint function
     */
    function _mintTokens(address to, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            _safeMint(to, tokenId);
            
            // 기본 메타데이터 URI 설정
            string memory defaultURI = string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId), ".json"));
            _setTokenURI(tokenId, defaultURI);
            
            emit NFTMinted(to, tokenId, defaultURI);
        }
        
        mintedByWallet[to] += quantity;
    }
    
    /**
     * @dev Toggle public sale
     */
    function togglePublicSale() external onlyOwner {
        publicSaleActive = !publicSaleActive;
        emit PublicSaleToggled(publicSaleActive);
    }
    
    /**
     * @dev Toggle whitelist sale
     */
    function toggleWhitelistSale() external onlyOwner {
        whitelistSaleActive = !whitelistSaleActive;
        emit WhitelistSaleToggled(whitelistSaleActive);
    }
    
    /**
     * @dev Add addresses to whitelist
     */
    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
            emit WhitelistAdded(addresses[i]);
        }
    }
    
    /**
     * @dev Remove addresses from whitelist
     */
    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
            emit WhitelistRemoved(addresses[i]);
        }
    }
    
    /**
     * @dev Set base URI for metadata
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }
    
    /**
     * @dev Set contract URI for OpenSea
     */
    function setContractURI(string calldata contractURI) external onlyOwner {
        _contractURI = contractURI;
    }
    
    /**
     * @dev Returns contract URI for OpenSea
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
    
    /**
     * @dev Set individual token URI
     */
    function setTokenURI(uint256 tokenId, string calldata tokenURI) external onlyOwner {
        require(_exists(tokenId), "LJMCC: Token does not exist");
        _setTokenURI(tokenId, tokenURI);
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Withdraw contract balance
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "LJMCC: No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "LJMCC: Withdrawal failed");
        
        emit Withdrawal(owner(), balance);
    }
    
    /**
     * @dev Returns remaining mintable supply
     */
    function remainingSupply() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    /**
     * @dev Returns tokens owned by an address
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Override required by Solidity
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    /**
     * @dev Override required by Solidity
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    /**
     * @dev Override required by Solidity
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev Override required by Solidity
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Returns contract version
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
