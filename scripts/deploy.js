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
let whiteList = ["0x7440e1407f95F33206Fb72464A63cd54B2eE6282", "0x1Ef1B44A0EF21C8A4e9ff20f589A9a15C2253059",
 "0x1D3F83F3A37041a0963111Ed9ABFFCaeAD3a4d72", "0x8F4DE7C17047fa4578AC3D151cE9801cDcc5487F", "0x93f3fF49e1AF6B9f3267311c17243b23B93bc803",
 "0xA30D18C731c9944F904fFB1011c17B75280d2A08", "0xc234002b48C7CDa0843fb2e15CaAB0375BA82E5D", "0x08B9765eAb26db97fe781D5321E8840Ddb8bB2bD",
 "0x4E9262f514073642bb44470FECc7eB7bE6f77aE5", "0x9338827Dd914cD5d6d8faebA2064e66Fc1d102d6", "0xc03C12101AE20B8e763526d6841Ece893248a069", 
 "0xb47d5C16B37CaD20573Db593F03e4C3387b5060B", "0x44b35738941fA2e087d36959b781f35F75d0A5a6", "0x2c41cE44BDB1ad9232040587632D81dA860A2A81"]
let newOwner = "0xc03C12101AE20B8e763526d6841Ece893248a069";
let opensea = "0x1E0049783F008A0085193E00003D00cd54003c71";
async function main() {
  let AdamNFT = await ethers.getContractFactory("AdamNFT");
  nft = await AdamNFT.deploy("XBOX", "XBOX", 50, 30);
  await nft.deployTransaction.wait()
  console.log("deploy nft");

  let leafNodes = whiteList.map(v => keccak256(v));
  const merkleTree = new MerkleTree(leafNodes, keccak256, {sort: true});
  const rootHash = merkleTree.getRoot()
  await (await nft.setMerkleRoot(rootHash)).wait();
  await (await nft.setBaseURI("ipfs://QmddGvvLFMcPE3qw1QRyFSadwmxPePY1bwYosDqyUvqkzv/")).wait()

  console.log("deploy trade");

  let AdamTrade = await ethers.getContractFactory("AdamTrade");
  trade = await AdamTrade.deploy(nft.address);
  await trade.deployTransaction.wait()
  console.log("init");
  await (await nft.setAddress(opensea, trade.address, owner)).wait()
  console.log(`nft:${nft.address}\ntrade:${trade.address}`)
  await (await nft.transferOwnership(newOwner)).wait();
  await (await trade.transferOwnership(newOwner)).wait();
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
