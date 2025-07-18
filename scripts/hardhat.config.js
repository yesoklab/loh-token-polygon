require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  
  networks: {
    // 로컬 개발 네트워크
    hardhat: {
      chainId: 31337,
    },
    
    // Polygon Mumbai 테스트넷
    mumbai: {
      url: process.env.MUMBAI_RPC_URL || "https://rpc-mumbai.maticvigil.com",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 80001,
      gasPrice: 35000000000, // 35 gwei
    },
    
    // Polygon 메인넷
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 137,
      gasPrice: 35000000000, // 35 gwei
    },
    
    // Ethereum 메인넷 (향후 확장용)
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
    },
  },
  
  // Etherscan 검증 설정
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
    },
  },
  
  // Gas 리포터 설정
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  
  // 컨트랙트 크기 체크
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  
  // 경로 설정
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  
  // 모카 테스트 설정
  mocha: {
    timeout: 40000,
  },
  
  // LOH Token 프로젝트 설정
  defaultNetwork: "hardhat",
  
  // 추가 정보
  metadata: {
    projectName: "LOH Token Project",
    description: "이재명 대통령 1시간 = 국민 51,169,148명",
    totalSupply: "51169148000000000000000000", // 51,169,148 토큰
    nftSupply: 5800,
    contact: {
      email: "YesOkLab@gmail.com",
      telegram: "t.me/YesOkLab_NFT",
      github: "https://github.com/yesoklab/loh-token-polygon"
    }
  }
};
