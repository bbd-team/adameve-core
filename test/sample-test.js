const { expect } = require("chai");
const { ethers, waffle} = require("hardhat");
const provider = waffle.provider;
const moment = require("moment");
let BN = require("bignumber.js");
let address0 = "0x0000000000000000000000000000000000000000";
const {MerkleTree} = require('merkletreejs')
const keccak256 = require('keccak256');

function toTokenAmount(amount, decimals = 18) {
    return new BN(amount).multipliedBy(new BN("10").pow(decimals)).toFixed()
}

const toMathAmount = (amount, decimals = 18) => new BN(amount.toString()).dividedBy(new BN(Math.pow(10, decimals))).toFixed();

describe("NFT", function () {
  let nft, trade, weth9;
  let developer, user1, user2, user3, user4, inviter;

  before(async () => {
      [developer, user1, user2, user3, user4, inviter] = await ethers.getSigners()

      let AdamNFT = await ethers.getContractFactory("AdamNFT");
      nft = await AdamNFT.deploy("XBOX", "XBOX", 15, 5);

      let WETH9 = await ethers.getContractFactory("WETH9");
      weth9 = await WETH9.deploy();

      let AdamTrade = await ethers.getContractFactory("AdamTrade");
      trade = await AdamTrade.deploy(nft.address);
      await (await nft.setAddress(user3.address, trade.address, developer.address))
  });

  async function logBalance(user) {
      console.log(`balance ${toMathAmount(await provider.getBalance(user.address))}`)
      console.log(`contract ${toMathAmount(await provider.getBalance(nft.address))}`)
      console.log(`inviter ${toMathAmount(await provider.getBalance(inviter.address))}`)

      let closeTime = await nft.closeTime();
      console.log(`close time ${moment(closeTime,'s').format()}`)

      let price = await nft.price();
      console.log(`price ${toMathAmount(price)}`)

      let share = await nft.pricePerShare();
      console.log(`share ${toMathAmount(share)}`)
  }

  async function logBalanceTrade(user, name = "user4") {
      console.log(`balance ${name} ${toMathAmount(await provider.getBalance(user.address))}`)
      console.log(`contract ${toMathAmount(await provider.getBalance(trade.address))}`)
      console.log(`inviter ${toMathAmount(await provider.getBalance(inviter.address))}`)

      let closeTime = await trade.closeTime();
      console.log(`close time ${moment(closeTime,'s').format()}`)

      let grandPool = await trade.grandPool();
      console.log(`grandPool ${grandPool}`);
  }

  it("simple premint", async function() {
      await (await nft.changeStatus(1)).wait();

      let leafNodes = [user1.address, user2.address].map(v => keccak256(v));
      const merkleTree = new MerkleTree(leafNodes, keccak256, {sort: true});
      const rootHash = merkleTree.getRoot()
      await (await nft.setMerkleRoot(rootHash)).wait();

      await logBalance(developer);
      let proof = merkleTree.getHexProof(keccak256(user1.address))
      await (await nft.connect(user1).premint(5, inviter.address, proof, {value: toTokenAmount(10)})).wait();

      proof = merkleTree.getHexProof(keccak256(user2.address))
      await (await nft.connect(user2).premint(3, inviter.address, proof, {value: toTokenAmount(10)})).wait();

      proof = merkleTree.getHexProof(keccak256(user1.address))
      await expect(nft.connect(user1).premint(1, inviter.address, proof, {value: toTokenAmount(10)}))
        .to.be.revertedWith('Limit exceed')

      proof = merkleTree.getHexProof(keccak256(user3.address))
      await expect(nft.connect(user3).premint(3, inviter.address, proof, {value: toTokenAmount(10)}))
        .to.be.revertedWith('Invalid proof')

       await logBalance(developer);
        console.log("premint");
  })

  it("simple mint", async function () {
        await (await nft.changeStatus(2)).wait();
        await logBalance(developer);

        await (await nft.connect(user2).mint(2, inviter.address, {value: toTokenAmount(10)})).wait();
        await logBalance(user2);

        await (await nft.connect(user3).mint(5, inviter.address, {value: toTokenAmount(10)})).wait();
        await logBalance(user3);

        await (await nft.changeStatus(3)).wait();

        console.log('closed');
        console.log('claim grand')
        await (await nft.connect(user3).claimGrand([11, 12, 13, 14, 15])).wait();
        await logBalance(user3);

        await (await nft.connect(user2).claimGrand([6, 7, 8, 9, 10])).wait();
        await logBalance(user2);

        // console.log('claim share');
        // await logBalance(user1);
        // await (await nft.connect(user1).claimShare([1, 2, 3, 4, 5])).wait();
        // await logBalance(user1);

        // await (await nft.connect(user2).claimShare([6, 7, 8, 9, 10])).wait();
        // await logBalance(user2);

        // await (await nft.connect(user3).claimShare([11, 12, 13, 14, 15])).wait();
        // await logBalance(user3);

        console.log('claim dev')
        await (await nft.claimDev()).wait(); 
        await logBalance(user3);

   });

  it("simple trade", async function() {
    console.log('\n\n');
      await (await trade.changeStatus(1)).wait();
      await logBalanceTrade(user4);

      await nft.connect(user3).transferFrom(user3.address, user4.address, 11);
      await nft.connect(user3).transferFrom(user3.address, user4.address, 12);
      await nft.connect(user3).transferFrom(user3.address, user4.address, 13);

      // await (await trade.connect(user4).claimShare([11, 12, 13])).wait();
      await expect(trade.connect(user4).claimShare([11, 12, 13]))
        .to.be.revertedWith('Not closed')

      await logBalanceTrade(user4);
      await (await trade.changeStatus(2)).wait();
      console.log("close");

      await (await trade.addGrandReward(toTokenAmount(3000), {value: toTokenAmount(3000)})).wait();
      await (await trade.addShareReward(toTokenAmount(1000), {value: toTokenAmount(1000)})).wait();
      await logBalanceTrade(user4);

      console.log("claim trade grand")
      await (await trade.connect(user4).claimGrand([11, 12, 13])).wait();
        await logBalanceTrade(user4);

        console.log("claim trade share")
        await (await trade.connect(user4).claimShare([11, 12, 13])).wait();
        await logBalanceTrade(user4);

        await (await trade.connect(user3).claimShare([14, 15])).wait();
        await logBalanceTrade(user3, "user3");

        await (await trade.connect(user1).claimShare([1, 2, 3, 4, 5])).wait();
        await logBalanceTrade(user1, "user1");

        await (await trade.connect(user2).claimShare([6, 7, 8, 9, 10])).wait();
        await logBalanceTrade(user2, "user2");

      await expect(trade.connect(user4).claimShare([11, 12, 13]))
        .to.be.revertedWith('No remain share amount')

        await (await trade.addShareReward(toTokenAmount(1000), {value: toTokenAmount(1000)})).wait();
        await (await trade.connect(user4).claimShare([11, 12, 13])).wait();
        await logBalanceTrade(user4);
  })

});
