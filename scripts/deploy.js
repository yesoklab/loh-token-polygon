const { ethers } = require("hardhat");

async function main() {
  console.log("=== LOH Token 배포 시작 ===");
  console.log("프로젝트: 이재명 대통령 1시간 = 국민 51,169,148명");
  
  // 배포할 계정 정보 출력
  const [deployer] = await ethers.getSigners();
  console.log("배포 계정:", deployer.address);
  console.log("계정 잔액:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  // LOH Token 컨트랙트 팩토리 가져오기
  const LOHToken = await ethers.getContractFactory("LOHToken");
  
  console.log("\n🚀 LOH Token 배포 중...");
  
  // 컨트랙트 배포 (총 공급량: 51,169,148 토큰)
  const lohToken = await LOHToken.deploy();
  await lohToken.deployed();
  
  console.log("✅ LOH Token 배포 완료!");
  console.log("📍 컨트랙트 주소:", lohToken.address);
  console.log("🔢 총 공급량:", ethers.utils.formatEther(await lohToken.totalSupply()), "LOH");
  
  // LJM Clockwork Collection NFT 배포 (선택사항)
  try {
    const LJMCollection = await ethers.getContractFactory("LJMClockworkCollection");
    console.log("\n🎨 LJM Clockwork Collection 배포 중...");
    
    const ljmCollection = await LJMCollection.deploy();
    await ljmCollection.deployed();
    
    console.log("✅ LJM Clockwork Collection 배포 완료!");
    console.log("📍 NFT 컨트랙트 주소:", ljmCollection.address);
    console.log("🖼️ 최대 공급량: 5,800개 NFT");
  } catch (error) {
    console.log("⚠️ NFT 컨트랙트 배포 건너뜀 (파일이 없을 수 있음)");
  }
  
  console.log("\n=== 배포 완료 ===");
  console.log("GitHub: https://github.com/yesoklab/loh-token-polygon");
  console.log("Contact: YesOkLab@gmail.com | t.me/YesOkLab_NFT");
}

// 배포 실행
main()
  .then(() => {
    console.log("🎉 배포 성공!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 배포 실패:", error);
    process.exit(1);
  });
