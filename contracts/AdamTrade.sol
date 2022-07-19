//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IAdamNFT.sol";
import "./interfaces/IWETH9.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AdamTrade is Ownable, ReentrancyGuard {
    using SafeMath for uint;

    enum Status { Ready, Open, Close } 

    uint constant public MaxTime = 2 * 24 * 60 * 60;
    uint constant public AddTime = 10 * 60;
    uint constant public GrandIds = 10;
    uint public closeTime;
    uint[10] public grandPercent = [25, 17, 13, 11, 9, 7, 6, 5, 4, 3];
    Status public status = Status.Ready;
    string public uri;
    uint public grandPool;
    uint public sharePool;
    uint constant public MAG = 1e18;
    uint public cnt;
    address public nft;

    EnumerableSet.UintSet private grandSet;

    struct NFTInfo {
        uint shareDebt;
        uint grandDebt;
        uint grandIdx;
    }

    mapping(uint => NFTInfo) public nfts;
    event SetAddress(address opensea, address trade, address dev);
    event Mint(address user, uint tokenId, uint price);
    event Open();
    event Close();
    event ClaimShare(address user, uint[] ids, uint amount);
    event ClaimGrandPool(address user, uint[] ids, uint amount);
    event AddGrandReward(uint amount);
    event AddShareReward(uint amount);
    event Transfer(address to, uint tokenId);

    constructor(address _nft) {
        nft = _nft;
    }

    receive() external payable {
    }

    function emergencyWithdraw(uint amount) external onlyOwner {
        _transferEther(msg.sender, amount);
    }

    function changeStatus(Status _status) external onlyOwner {
        status = _status;
        if(_status == Status.Open) {
            // grandPool = grandPool.add(address(this).balance);
            closeTime = block.timestamp.add(MaxTime);
            cnt = IAdamNFT(nft).lastId();
            emit Open();
        } else if(_status == Status.Close) {
            // require(block.timestamp > closeTime, "Cannot close now");
            uint l = EnumerableSet.length(grandSet);
            for(uint i = 0; i < l;i++) {
                nfts[EnumerableSet.at(grandSet, i)].grandIdx = l - i - 1;
            }
            emit Close();
        }
    }

    function notify(address to, uint tokenId) external {
        if(msg.sender == address(nft) && status == Status.Open && block.timestamp <= closeTime) {
            if(EnumerableSet.contains(grandSet, tokenId)) {
                EnumerableSet.remove(grandSet, tokenId);
            } 
            if(EnumerableSet.length(grandSet) == GrandIds) {
                EnumerableSet.remove(grandSet, EnumerableSet.at(grandSet, 0));
            }
            
            EnumerableSet.add(grandSet, tokenId);
            closeTime = closeTime.add(AddTime);
            if(closeTime > block.timestamp + MaxTime) {
                closeTime = block.timestamp + MaxTime;
            }

            emit Transfer(to, tokenId);
        }
    }

    function claimShare(uint[] memory ids)  external nonReentrant returns(uint amount)  {
        uint l = ids.length;
        require(l > 0, "Invalid");
        require(status == Status.Close, "Not closed");
        for(uint i = 0;i < l;i++) {
            NFTInfo storage info = nfts[ids[i]];
            require(IERC721(nft).ownerOf(ids[i]) == msg.sender, 'Not owner');
            (uint tokenShare, uint totalShare) = IAdamNFT(nft).getShare(ids[i]);
            amount = amount.add(sharePool.sub(info.shareDebt).mul(tokenShare).div(totalShare));
            info.shareDebt = sharePool;
        }

        require(amount > 0, "No remain share amount");
        _transferEther(msg.sender, amount);
        emit ClaimShare(msg.sender, ids, amount);
    }

    function claimGrand(uint[] memory ids) external nonReentrant returns(uint amount)  {
        require(status == Status.Close, "Not closed");
        uint l = ids.length;
        require(l > 0, "Invalid");
        for(uint i = 0;i < l;i++) {
            NFTInfo storage info = nfts[ids[i]];
            require(EnumerableSet.contains(grandSet, ids[i]), "Not grand prize id");
            require(IERC721(nft).ownerOf(ids[i]) == msg.sender, 'Not owner');
            amount = amount.add(grandPool.sub(info.grandDebt).mul(grandPercent[info.grandIdx]).div(100));
            info.grandDebt = grandPool;
        }
        
        require(amount > 0, "No remain grand amount");
        _transferEther(msg.sender, amount);
        emit ClaimGrandPool(msg.sender, ids, amount);
    }

    function _transferEther(address to, uint amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function addGrandReward(uint amount) payable external {
        require(msg.value == amount, "Invalid value");
        grandPool = grandPool.add(amount);
        emit AddGrandReward(amount);
    }

    function addShareReward(uint amount) payable external {
        require(msg.value == amount, "Invalid value");
        sharePool = sharePool.add(amount);
        emit AddShareReward(amount);
    }
}
