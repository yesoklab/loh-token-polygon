const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LOH Token Contract", function () {
  let LOHToken;
  let lohToken;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  // 테스트 상수
  const TOTAL_SUPPLY = ethers.utils.parseEther("51169148"); // 51,169,148 LOH
  const TOKEN_NAME = "LOH Token";
  const TOKEN_SYMBOL = "LOH";
  const DECIMALS = 18;

  beforeEach(async function () {
    console.log("\n=== LOH Token 테스트 시작 ===");
    console.log("프로젝트: 이재명 대통령 1시간 = 국민 51,169,148명");

    // 계정 설정
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // LOH Token 컨트랙트 배포
    LOHToken = await ethers.getContractFactory("LOHToken");
    lohToken = await LOHToken.deploy();
    await lohToken.deployed();

    console.log("✅ LOH Token 테스트 컨트랙트 배포 완료");
    console.log("📍 컨트랙트 주소:", lohToken.address);
    console.log("👤 Owner 주소:", owner.address);
  });

  describe("배포 및 기본 정보", function () {
    it("토큰 이름이 올바르게 설정되어야 함", async function () {
      expect(await lohToken.name()).to.equal(TOKEN_NAME);
    });

    it("토큰 심볼이 올바르게 설정되어야 함", async function () {
      expect(await lohToken.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("소수점 자릿수가 18이어야 함", async function () {
      expect(await lohToken.decimals()).to.equal(DECIMALS);
    });

    it("총 공급량이 51,169,148 LOH여야 함", async function () {
      const totalSupply = await lohToken.totalSupply();
      expect(totalSupply).to.equal(TOTAL_SUPPLY);
      
      console.log("🔢 총 공급량:", ethers.utils.formatEther(totalSupply), "LOH");
    });

    it("Owner가 모든 토큰을 보유해야 함", async function () {
      const ownerBalance = await lohToken.balanceOf(owner.address);
      expect(ownerBalance).to.equal(TOTAL_SUPPLY);
      
      console.log("💰 Owner 잔액:", ethers.utils.formatEther(ownerBalance), "LOH");
    });
  });

  describe("토큰 전송", function () {
    it("토큰을 다른 주소로 전송할 수 있어야 함", async function () {
      const transferAmount = ethers.utils.parseEther("1000");
      
      await lohToken.transfer(addr1.address, transferAmount);
      
      const addr1Balance = await lohToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(transferAmount);
      
      console.log("✅ 전송 성공:", ethers.utils.formatEther(transferAmount), "LOH → addr1");
    });

    it("잔액이 부족하면 전송이 실패해야 함", async function () {
      const invalidAmount = TOTAL_SUPPLY.add(1);
      
      await expect(
        lohToken.connect(addr1).transfer(addr2.address, invalidAmount)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("전송 시 Transfer 이벤트가 발생해야 함", async function () {
      const transferAmount = ethers.utils.parseEther("500");
      
      await expect(lohToken.transfer(addr1.address, transferAmount))
        .to.emit(lohToken, "Transfer")
        .withArgs(owner.address, addr1.address, transferAmount);
    });
  });

  describe("승인 및 위임 전송", function () {
    it("승인을 통한 위임 전송이 가능해야 함", async function () {
      const approveAmount = ethers.utils.parseEther("2000");
      const transferAmount = ethers.utils.parseEther("1500");
      
      // Owner가 addr1에게 승인
      await lohToken.approve(addr1.address, approveAmount);
      
      // addr1이 Owner로부터 addr2에게 전송
      await lohToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount);
      
      const addr2Balance = await lohToken.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(transferAmount);
      
      // 남은 승인량 확인
      const remainingAllowance = await lohToken.allowance(owner.address, addr1.address);
      expect(remainingAllowance).to.equal(approveAmount.sub(transferAmount));
      
      console.log("✅ 위임 전송 성공:", ethers.utils.formatEther(transferAmount), "LOH");
    });

    it("승인량을 초과하는 위임 전송은 실패해야 함", async function () {
      const approveAmount = ethers.utils.parseEther("1000");
      const invalidTransferAmount = ethers.utils.parseEther("1500");
      
      await lohToken.approve(addr1.address, approveAmount);
      
      await expect(
        lohToken.connect(addr1).transferFrom(owner.address, addr2.address, invalidTransferAmount)
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });
  });

  describe("특수 기능 테스트", function () {
    it("대량 토큰 전송이 정상적으로 처리되어야 함", async function () {
      const largeAmount = ethers.utils.parseEther("10000000"); // 1천만 LOH
      
      await lohToken.transfer(addr1.address, largeAmount);
      
      const addr1Balance = await lohToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(largeAmount);
      
      console.log("🚀 대량 전송 성공:", ethers.utils.formatEther(largeAmount), "LOH");
    });

    it("이재명 대통령 컨셉 검증: 51,169,148개 정확히 발행", async function () {
      const conceptMessage = "이재명 대통령 1시간 = 국민 51,169,148명";
      const totalSupply = await lohToken.totalSupply();
      const expectedSupply = ethers.utils.parseEther("51169148");
      
      expect(totalSupply).to.equal(expectedSupply);
      
      console.log("🇰🇷", conceptMessage);
      console.log("🎯 발행량 검증 완료:", ethers.utils.formatEther(totalSupply), "LOH");
    });
  });

  describe("보안 테스트", function () {
    it("0 주소로의 전송이 차단되어야 함", async function () {
      const transferAmount = ethers.utils.parseEther("100");
      
      await expect(
        lohToken.transfer(ethers.constants.AddressZero, transferAmount)
      ).to.be.revertedWith("ERC20: transfer to the zero address");
    });

    it("컨트랙트 상태가 일관성을 유지해야 함", async function () {
      const initialSupply = await lohToken.totalSupply();
      const initialOwnerBalance = await lohToken.balanceOf(owner.address);
      
      // 여러 전송 수행
      await lohToken.transfer(addr1.address, ethers.utils.parseEther("1000"));
      await lohToken.transfer(addr2.address, ethers.utils.parseEther("2000"));
      
      // 총 공급량은 변하지 않아야 함
      const finalSupply = await lohToken.totalSupply();
      expect(finalSupply).to.equal(initialSupply);
      
      // 모든 잔액의 합은 총 공급량과 같아야 함
      const ownerBalance = await lohToken.balanceOf(owner.address);
      const addr1Balance = await lohToken.balanceOf(addr1.address);
      const addr2Balance = await lohToken.balanceOf(addr2.address);
      
      const totalBalances = ownerBalance.add(addr1Balance).add(addr2Balance);
      expect(totalBalances).to.equal(finalSupply);
      
      console.log("🔒 보안 검증 완료: 상태 일관성 유지");
    });
  });

  after(function () {
    console.log("\n=== LOH Token 테스트 완료 ===");
    console.log("GitHub: https://github.com/yesoklab/loh-token-polygon");
    console.log("Contact: YesOkLab@gmail.com | t.me/YesOkLab_NFT");
  });
});
