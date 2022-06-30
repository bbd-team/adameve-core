// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
let nft;
const {MerkleTree} = require('merkletreejs')
const keccak256 = require('keccak256');
let owner = "0x892a2b7cF919760e148A0d33C1eb0f44D3b383f8";
let address0 = "0x0000000000000000000000000000000000000000";
let whiteList = ["0xc03C12101AE20B8e763526d6841Ece893248a069", "0x2c41cE44BDB1ad9232040587632D81dA860A2A81", "0x9338827Dd914cD5d6d8faebA2064e66Fc1d102d6"]
let newOwner = "0xc03C12101AE20B8e763526d6841Ece893248a069";
async function main() {
  let AdamNFT = await ethers.getContractFactory("AdamNFT");
  nft = await AdamNFT.deploy("XBOX", "XBOX", 50);

  console.log("setup");
  await (await nft.setAddress(address0, address0, owner))

  let leafNodes = whiteList.map(v => keccak256(v));
  const merkleTree = new MerkleTree(leafNodes, keccak256, {sort: true});
  const rootHash = merkleTree.getRoot()
  await (await nft.setMerkleRoot(rootHash)).wait();
  await (await nft.transferOwnership(newOwner));
  console.log(`nft:${nft.address}`)
  console.log("complete");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
