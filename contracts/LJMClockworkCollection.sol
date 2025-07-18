// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title LJM Clockwork Heritage Collection
 * @dev Project LJM Clockwork 디지털 유산 아카이빙 NFT 컬렉션
 * @notice 이재명 대통령 1시간 = 대한민국 국민 시간을 담은 NFT 컬렉션
 */
contract LJMClockworkCollection is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    Ownable, 
    ReentrancyGuard, 
    Pausable,
    IERC2981 
{
    
    // ===== 기본 설정 =====
    IERC20 public lohToken; // LOH 토큰 컨트랙트
    uint256 public constant MAX_SUPPLY = 5800; // 총 5,800개
    uint256 public currentTokenId = 0;
    
    // ===== NFT 등급 시스템 =====
    enum NFTRarity {
        LEGENDARY,    // 1개
        EPIC,        // 99개
        RARE,        // 700개
        COMMON       // 5,000개
    }
    
    struct NFTInfo {
        NFTRarity rarity;
        uint256 price;         // LOH 토큰 가격
        uint256 mintedAt;
        string category;       // 카테고리 (시계, 캘리그래피, 타이포그래피)
        bool isWatchFace;      // 스마트워치 페이스 여부
        string heritage;       // 유산 설명
    }
    
    mapping(uint256 => NFTInfo) public nftInfo;
    mapping(NFTRarity => uint256) public rarityCount;
    mapping(NFTRarity => uint256) public rarityPrice;
    mapping(NFTRarity => uint256) public rarityLimit;
    
    // ===== 세일 단계 =====
    enum SalePhase {
        NotStarted,
        Presale,
        PublicSale,
        Ended
    }
    
    SalePhase public currentPhase = SalePhase.NotStarted;
    
    // ===== 화이트리스트 & 프리세일 =====
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public presaleMinted;
    uint256 public presaleMaxPerWallet = 3;
    uint256 public publicMaxPerWallet = 10;
    mapping(address => uint256) public publicMinted;
    
    // ===== 로열티 설정 =====
    uint256 public royaltyPercentage = 750; // 7.5%
    address public royaltyReceiver;
    
    // ===== 카테고리별 관리 =====
    string[] public categories = ["ClockFace", "Calligraphy", "Typography", "Heritage", "Special"];
    mapping(string => uint256) public categoryCount;
    mapping(string => uint256) public categoryLimit;
    
    // ===== 이벤트 =====
    event NFTMinted(uint256 indexed tokenId, address indexed to, NFTRarity rarity, string category, uint256 price);
    event PhaseChanged(SalePhase newPhase);
    event WhitelistUpdated(address indexed user, bool status);
    event RoyaltyUpdated(address receiver, uint256 percentage);
    event PriceUpdated(NFTRarity rarity, uint256 newPrice);
    
    constructor(
        address _lohToken,
        address _royaltyReceiver
    ) ERC721("LJM Clockwork Heritage Collection", "LJMCLOCK") {
        lohToken = IERC20(_lohToken);
        royaltyReceiver = _royaltyReceiver;
        
        // 등급별 한도 설정
        rarityLimit[NFTRarity.LEGENDARY] = 1;
        rarityLimit[NFTRarity.EPIC] = 99;
        rarityLimit[NFTRarity.RARE] = 700;
        rarityLimit[NFTRarity.COMMON] = 5000;
        
        // 등급별 가격 설정 (LOH 토큰)
        rarityPrice[NFTRarity.LEGENDARY] = 100000 * 10**18;  // 100,000 LOH
        rarityPrice[NFTRarity.EPIC] = 10000 * 10**18;       // 10,000 LOH
        rarityPrice[NFTRarity.RARE] = 1000 * 10**18;        // 1,000 LOH
        rarityPrice[NFTRarity.COMMON] = 100 * 10**18;       // 100 LOH
        
        // 카테고리별 한도 설정
        categoryLimit["ClockFace"] = 5000;      // 스마트워치 페이스
        categoryLimit["Calligraphy"] = 400;     // 캘리그래피
        categoryLimit["Typography"] = 300;      // 타이포그래피
        categoryLimit["Heritage"] = 99;         // 디지털 유산
        categoryLimit["Special"] = 1;           // 특별 에디션
    }
    
    // ===== 민팅 기능 =====
    
    /**
     * @dev 프리세일 민팅
     */
    function presaleMint(
        NFTRarity _rarity,
        string memory _category,
        string memory _tokenURI,
        string memory _heritage,
        bool _isWatchFace
    ) external nonReentrant whenNotPaused {
        require(currentPhase == SalePhase.Presale, "Presale not active");
        require(whitelist[msg.sender], "Not whitelisted");
        require(presaleMinted[msg.sender] < presaleMaxPerWallet, "Presale limit exceeded");
        require(currentTokenId < MAX_SUPPLY, "Max supply reached");
        require(rarityCount[_rarity] < rarityLimit[_rarity], "Rarity limit exceeded");
        require(categoryCount[_category] < categoryLimit[_category], "Category limit exceeded");
        
        uint256 price = rarityPrice[_rarity];
        uint256 presalePrice = (price * 80) / 100; // 20% 할인
        
        require(lohToken.balanceOf(msg.sender) >= presalePrice, "Insufficient LOH balance");
        require(lohToken.transferFrom(msg.sender, address(this), presalePrice), "LOH transfer failed");
        
        _mintNFT(msg.sender, _rarity, _category, _tokenURI, _heritage, _isWatchFace, presalePrice);
        presaleMinted[msg.sender]++;
    }
    
    /**
     * @dev 퍼블릭 세일 민팅
     */
    function publicMint(
        NFTRarity _rarity,
        string memory _category,
        string memory _tokenURI,
        string memory _heritage,
        bool _isWatchFace
    ) external nonReentrant whenNotPaused {
        require(currentPhase == SalePhase.PublicSale, "Public sale not active");
        require(publicMinted[msg.sender] < publicMaxPerWallet, "Public limit exceeded");
        require(currentTokenId < MAX_SUPPLY, "Max supply reached");
        require(rarityCount[_rarity] < rarityLimit[_rarity], "Rarity limit exceeded");
        require(categoryCount[_category] < categoryLimit[_category], "Category limit exceeded");
        
        uint256 price = rarityPrice[_rarity];
        require(lohToken.balanceOf(msg.sender) >= price, "Insufficient LOH balance");
        require(lohToken.transferFrom(msg.sender, address(this), price), "LOH transfer failed");
        
        _mintNFT(msg.sender, _rarity, _category, _tokenURI, _heritage, _isWatchFace, price);
        publicMinted[msg.sender]++;
    }
    
    /**
     * @dev 특별 에디션 민팅 (관리자만)
     */
    function mintSpecialEdition(
        address _to,
        NFTRarity _rarity,
        string memory _category,
        string memory _tokenURI,
        string memory _heritage,
        bool _isWatchFace
    ) external onlyOwner {
        require(currentTokenId < MAX_SUPPLY, "Max supply reached");
        require(rarityCount[_rarity] < rarityLimit[_rarity], "Rarity limit exceeded");
        
        _mintNFT(_to, _rarity, _category, _tokenURI, _heritage, _isWatchFace, 0);
    }
    
    /**
     * @dev 내부 민팅 함수
     */
    function _mintNFT(
        address _to,
        NFTRarity _rarity,
        string memory _category,
        string memory _tokenURI,
        string memory _heritage,
        bool _isWatchFace,
        uint256 _price
    ) internal {
        currentTokenId++;
        uint256 tokenId = currentTokenId;
        
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        nftInfo[tokenId] = NFTInfo({
            rarity: _rarity,
            price: _price,
            mintedAt: block.timestamp,
            category: _category,
            isWatchFace: _isWatchFace,
            heritage: _heritage
        });
        
        rarityCount[_rarity]++;
        categoryCount[_category]++;
        
        emit NFTMinted(tokenId, _to, _rarity, _category, _price);
    }
    
    // ===== 배치 민팅 (관리자용) =====
    
    /**
     * @dev 스마트워치 페이스 배치 민팅
     */
    function batchMintWatchFaces(
        address[] memory _recipients,
        string[] memory _tokenURIs,
        string[] memory _heritages
    ) external onlyOwner {
        require(_recipients.length == _tokenURIs.length, "Array length mismatch");
        require(_recipients.length == _heritages.length, "Array length mismatch");
        require(_recipients.length <= 100, "Too many tokens"); // 가스 한도 고려
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (currentTokenId < MAX_SUPPLY && 
                rarityCount[NFTRarity.COMMON] < rarityLimit[NFTRarity.COMMON] &&
                categoryCount["ClockFace"] < categoryLimit["ClockFace"]) {
                
                _mintNFT(
                    _recipients[i],
                    NFTRarity.COMMON,
                    "ClockFace",
                    _tokenURIs[i],
                    _heritages[i],
                    true,
                    0
                );
            }
        }
    }
    
    // ===== 조회 기능 =====
    
    /**
     * @dev 사용자가 보유한 특정 등급 NFT 조회
     */
    function getTokensByRarity(address _owner, NFTRarity _rarity) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory result = new uint256[](tokenCount);
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            if (nftInfo[tokenId].rarity == _rarity) {
                result[resultIndex] = tokenId;
                resultIndex++;
            }
        }
        
        // 결과 배열 크기 조정
        uint256[] memory trimmedResult = new uint256[](resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            trimmedResult[i] = result[i];
        }
        
        return trimmedResult;
    }
    
    /**
     * @dev 카테고리별 NFT 조회
     */
    function getTokensByCategory(address _owner, string memory _category) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory result = new uint256[](tokenCount);
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            if (keccak256(bytes(nftInfo[tokenId].category)) == keccak256(bytes(_category))) {
                result[resultIndex] = tokenId;
                resultIndex++;
            }
        }
        
        uint256[] memory trimmedResult = new uint256[](resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            trimmedResult[i] = result[i];
        }
        
        return trimmedResult;
    }
    
    /**
     * @dev NFT 상세 정보 조회
     */
    function getNFTInfo(uint256 _tokenId) external view returns (NFTInfo memory) {
        require(_exists(_tokenId), "Token does not exist");
        return nftInfo[_tokenId];
    }
    
    /**
     * @dev 등급별 통계 조회
     */
    function getRarityStats() external view returns (
        uint256 legendaryCount,
        uint256 epicCount,
        uint256 rareCount,
        uint256 commonCount
    ) {
        return (
            rarityCount[NFTRarity.LEGENDARY],
            rarityCount[NFTRarity.EPIC],
            rarityCount[NFTRarity.RARE],
            rarityCount[NFTRarity.COMMON]
        );
    }
    
    // ===== 관리자 기능 =====
    
    /**
     * @dev 세일 단계 변경
     */
    function setPhase(SalePhase _phase) external onlyOwner {
        currentPhase = _phase;
        emit PhaseChanged(_phase);
    }
    
    /**
     * @dev 화이트리스트 추가/제거
     */
    function updateWhitelist(address[] memory _addresses, bool _status) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = _status;
            emit WhitelistUpdated(_addresses[i], _status);
        }
    }
    
    /**
     * @dev 등급별 가격 업데이트
     */
    function updateRarityPrice(NFTRarity _rarity, uint256 _newPrice) external onlyOwner {
        rarityPrice[_rarity] = _newPrice;
        emit PriceUpdated(_rarity, _newPrice);
    }
    
    /**
     * @dev 로열티 설정 업데이트
     */
    function updateRoyalty(address _receiver, uint256 _percentage) external onlyOwner {
        require(_percentage <= 1000, "Royalty too high"); // 최대 10%
        royaltyReceiver = _receiver;
        royaltyPercentage = _percentage;
        emit RoyaltyUpdated(_receiver, _percentage);
    }
    
    /**
     * @dev LOH 토큰 회수
     */
    function withdrawLOH() external onlyOwner {
        uint256 balance = lohToken.balanceOf(address(this));
        require(balance > 0, "No LOH to withdraw");
        lohToken.transfer(owner(), balance);
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
    
    // ===== 로열티 (EIP-2981) =====
    
    /**
     * @dev 로열티 정보 반환
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) 
        external view override returns (address, uint256) {
        require(_exists(_tokenId), "Token does not exist");
        uint256 royaltyAmount = (_salePrice * royaltyPercentage) / 10000;
        return (royaltyReceiver, royaltyAmount);
    }
    
    // ===== 오버라이드 함수들 =====
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete nftInfo[tokenId];
    }
    
    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721Enumerable, ERC721URIStorage, IERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
