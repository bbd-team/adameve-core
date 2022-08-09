//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IAdamTrade.sol";

contract AdamNFT is Ownable, ERC721Enumerable, ReentrancyGuard {
    using SafeMath for uint;

    enum Status { Ready, Premint, Open, Close } 

    uint public MaxTime = 12 * 60 * 60;
    uint constant public AddTime = 2 * 60;
    uint constant public PriceNumer = 10005;
    uint constant public PriceDenom = 10000;
    uint constant public GrandIds = 10;
    uint public mintLimit;
    uint[10] public grandPercent = [25, 17, 13, 11, 9, 7, 6, 5, 4, 3];
    uint public price = 1e14;
    Status public status = Status.Ready;
    uint public lastId = 0;
    uint public maxAmount;
    address public trade;
    address public opensea;
    address public dev;
    uint public closeTime;
    uint public totalShare = 0;
    string public uri;
    bool public devClaimed;
    uint public devPool;
    uint public grandPool;
    uint public sharePool;
    uint public tradePool;
    bytes32 public merkleRoot;
    uint public pricePerShare;
    uint constant public MAG = 1e18;

    struct NFTInfo {
        uint share;
        uint debt;
        bool shareClaimed;
        bool grandClaimed;
    }

    mapping(uint => NFTInfo) public nfts;
    mapping(address => uint) public users;
    event SetAddress(address opensea, address trade, address dev);
    event Mint(address user, uint tokenId, uint price);
    event Open();
    event Premint();
    event Close();
    event SetBaseURI(string uri);
    event ClaimShare(address user, uint[] ids, uint amount);
    event ClaimGrandPool(address user, uint[] ids, uint amount);
    event ClaimDevPool(address dev, uint amount);
    event ClaimTradePool(address trade, uint amount);
    event SetMerkleRoot(bytes32 root);
    event InviteReward(address buyer, address inviter, uint amount);

    constructor(
        string memory name,
        string memory symbol,
        uint _maxAmount,
        uint _mintLimit
    ) ERC721(name, symbol) {
        maxAmount = _maxAmount;
        mintLimit = _mintLimit;
    }

    function setAddress(address _opensea, address _trade, address _dev) external onlyOwner {
        opensea = _opensea;
        trade = _trade;
        dev = _dev;
        emit SetAddress(opensea, trade, dev);
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit SetMerkleRoot(root);
    }

    function isGrand(uint id) internal view returns(bool) {
        return id.add(GrandIds) > lastId;
    }

    function getShare(uint id) external view returns(uint, uint) {
        return (nfts[id].share, totalShare);
    }

    function changeStatus(Status _status) external onlyOwner {
        status = _status;
        if(status == Status.Open) {
            closeTime = block.timestamp + MaxTime;
            emit Open();
        } else if(status == Status.Close) {
            require(block.timestamp > closeTime || lastId == maxAmount, "Cannot close now");
            emit Close();
        } else if(status == Status.Premint) {
            emit Premint();
        }
    }

    function getReward(uint[] memory ids) external view returns(uint[] memory) {
        uint l = ids.length;
        uint[] memory amounts = new uint[](l);
        for(uint i = 0;i < l;i++) {
            NFTInfo memory info = nfts[ids[i]];
            amounts[i] = pricePerShare.sub(info.debt).mul(info.share).div(1e18);
        }

        return amounts;
    }
 
    function claimGrand(uint[] memory ids) external nonReentrant returns(uint amount) {
        require(status == Status.Close, "Not closed");
        uint l = ids.length;
        require(l > 0, "Invalid");
        for(uint i = 0;i < l;i++) {
            NFTInfo storage info = nfts[ids[i]];
            require(isGrand(ids[i]), "Not grand prize id");
            require(ownerOf(ids[i]) == msg.sender, 'Not owner');
            require(!info.grandClaimed, 'Already claimed');
            info.grandClaimed = true;
            uint idx = lastId.sub(ids[i]);
            amount = amount.add(grandPool.mul(grandPercent[idx]).div(100));
        }
        
        _transferEther(msg.sender, amount);
        emit ClaimGrandPool(msg.sender, ids, amount);
    }

    function claimDev() external onlyOwner {
        require(status == Status.Close, "Not closed");
        require(dev != address(0) && trade != address(0), "No address");
        require(!devClaimed, "Claimed");
        devClaimed = true;
        _transferEther(dev, devPool);
        _transferEther(trade, tradePool);
        emit ClaimDevPool(dev, devPool);
        emit ClaimTradePool(trade, tradePool);
    }

    function claimShare(uint[] memory ids) nonReentrant external returns(uint amount) {
        uint l = ids.length;
        require(l > 0, "Invalid");
        require(status == Status.Close, "Not closed");
        for(uint i = 0;i < l;i++) {
            NFTInfo storage info = nfts[ids[i]];
            require(ownerOf(ids[i]) == msg.sender, 'Not owner');
            require(!info.shareClaimed, 'Already claimed');
            info.shareClaimed = true;
            amount = amount.add(pricePerShare.sub(info.debt).mul(info.share).div(1e18));
        }
        _transferEther(msg.sender, amount);
        emit ClaimShare(msg.sender, ids, amount);
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        uri = _uri;
        emit SetBaseURI(_uri);
    }

    function contractURI() public pure returns (string memory) { 
        return "ipfs://QmWWyXUTXWEVBAL2FX2zXLAzEtC7Wc26HtJb6CKWKoRGh1"; 
    }

    function _distribute(uint amount) internal {
        if(totalShare == 0) {
            devPool = devPool.add(amount);
        } else {
            devPool = devPool.add(amount.div(10));
            tradePool = tradePool.add(amount.mul(5).div(100));
            grandPool = grandPool.add(amount.div(10));
            sharePool = sharePool.add(amount.mul(75).div(100));
            pricePerShare = pricePerShare.add(amount.mul(75).mul(1e18).div(100).div(totalShare));
        } 
    }

    function _mintProcess(address inviter, uint amount) internal {
        require(inviter != address(0) && inviter != msg.sender, "Invalid inviter");
        require(users[msg.sender].add(amount) <= mintLimit, "Limit exceed");
        uint pay = 0; 
        for(uint i = 0;i < amount;i++) {
            uint nftPrice = price;
            pay += nftPrice;
            lastId++;
            NFTInfo storage info = nfts[lastId];

            uint reward = nftPrice.mul(5).div(100);
            nftPrice = nftPrice.sub(reward);
            _transferEther(inviter, reward);
            emit InviteReward(msg.sender, inviter, reward);
            _distribute(nftPrice);
            
            _mint(msg.sender, lastId);
            info.share = nftPrice;
            info.debt = pricePerShare;
            emit Mint(msg.sender, lastId, nftPrice);
            price = price.mul(PriceNumer).div(PriceDenom);
        }

        require(msg.value >= pay, "Invalid pay");
        if(msg.value > pay) {
            _transferEther(msg.sender, msg.value.sub(pay));
        }
        users[msg.sender] = users[msg.sender].add(amount);
    }

    function premint(uint amount, address inviter, bytes32[] memory proof) payable external nonReentrant {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(status == Status.Premint, "Cannot premint now");
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
        _mintProcess(inviter, amount);
    }

    function mint(uint amount, address inviter) payable nonReentrant external {
        require(status == Status.Open && block.timestamp <= closeTime, "Not open or closed");
        require(lastId.add(amount) <= maxAmount, "Amount exceed");
        _mintProcess(inviter, amount);

        closeTime = closeTime.add(AddTime.mul(amount));
        if(closeTime > block.timestamp + MaxTime) {
            closeTime = block.timestamp + MaxTime;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return uri;
    }

    function _transferEther(address to, uint amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed.");
    }
 
    function _transfer (
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(status == Status.Close, "Cannot transfer nft now");
        super._transfer(from, to, tokenId);
        if(msg.sender == opensea && trade != address(0)) {
            IAdamTrade(trade).notify(to, tokenId);
        }
    }
}
