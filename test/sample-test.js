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
  let nft;
  let developer, user1, user2, user3;

  before(async () => {
      [developer, user1, user2, user3] = await ethers.getSigners()

      let AdamNFT = await ethers.getContractFactory("AdamNFT");
      nft = await AdamNFT.deploy("XBOX", "XBOX", 15);

      await (await nft.setAddress(address0, address0, developer.address))
  });

  async function logBalance(user) {
      console.log(`balance ${toMathAmount(await provider.getBalance(user.address))}`)
      console.log(`contract ${toMathAmount(await provider.getBalance(nft.address))}`)

      let closeTime = await nft.closeTime();
      console.log(`close time ${moment().format()}`)

      let price = await nft.price();
      console.log(`price ${toMathAmount(price)}`)

      let share = await nft.pricePerShare();
      console.log(`share ${toMathAmount(share)}`)
  }

  it("simple premint", async function() {
      await (await nft.changeStatus(1)).wait();

      let leafNodes = [user1.address, user2.address].map(v => keccak256(v));
      const merkleTree = new MerkleTree(leafNodes, keccak256, {sort: true});
      const rootHash = merkleTree.getRoot()
      await (await nft.setMerkleRoot(rootHash)).wait();

      let proof = merkleTree.getHexProof(keccak256(user1.address))
      await (await nft.connect(user1).premint(5, proof, {value: toTokenAmount(10)})).wait();

      proof = merkleTree.getHexProof(keccak256(user2.address))
      await (await nft.connect(user2).premint(3, proof, {value: toTokenAmount(10)})).wait();

      proof = merkleTree.getHexProof(keccak256(user1.address))
      await expect(nft.connect(user1).premint(1, proof, {value: toTokenAmount(10)}))
        .to.be.revertedWith('Limit exceed')

      proof = merkleTree.getHexProof(keccak256(user3.address))
      await expect(nft.connect(user3).premint(3, proof, {value: toTokenAmount(10)}))
        .to.be.revertedWith('Invalid proof')
  })

  it("simple mint", async function () {
        await (await nft.changeStatus(2)).wait();
        await logBalance(developer);

        await (await nft.connect(user2).mint(2, {value: toTokenAmount(10)})).wait();
        await logBalance(user2);

        await (await nft.connect(user3).mint(5, {value: toTokenAmount(10)})).wait();
        await logBalance(user3);

        await (await nft.changeStatus(3)).wait();

        console.log('closed');
        await logBalance(user1);
        await (await nft.connect(user1).claimShare([1, 2, 3, 4, 5])).wait();
        await logBalance(user1);

        await (await nft.connect(user2).claimShare([6, 7, 8, 9, 10])).wait();
        await logBalance(user2);

        await (await nft.connect(user3).claimShare([11, 12, 13, 14, 15])).wait();
        await logBalance(user3);

        console.log('claim grand')
        await (await nft.connect(user3).claimGrand([11, 12, 13, 14, 15])).wait();
        await logBalance(user3);
        console.log('claim dev')
        await (await nft.claimDev()).wait(); 
        await logBalance(user3);

   });


});
