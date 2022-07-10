//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IAdamNFT.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AdamTrade is Ownable, ReentrancyGuard {
    using SafeMath for uint;

    enum Status { Ready, Open, Close } 

    uint constant public MaxTime = 7 * 24 * 60 * 60;
    uint constant public AddTime = 10 * 60;
    uint constant public GrandIds = 10;
    uint public closeTime;

    Status public status = Status.Ready;
    address public nft;

    string public uri;
    uint public grandPool;
    uint public sharePool;
    uint public tradePool;
    uint constant public MAG = 1e18;
    uint public cnt;

    EnumerableSet.UintSet private grandSet;

    struct NFTInfo {
        uint shareDebt;
        uint grandDebt;
        bool shareClaimed;
        bool grandClaimed;
    }

    mapping(address => uint) public shareRewards;
    mapping(address => uint) public grandRewards;
    mapping(uint => NFTInfo) public nfts;
    event SetAddress(address opensea, address trade, address dev);
    event Mint(address user, uint tokenId, uint price);
    event Open();
    event Close();
    event ClaimShare(address user, uint[] ids, uint amount);
    event ClaimGrandPool(address user, uint[] ids, uint amount);
    event ClaimDevPool(address dev, uint amount);
    event AddReward(address token, uint amount);
    event Transfer(address to, uint tokenId);

    constructor(address _nft) {
        nft = _nft;
    }

    function changeStatus(Status _status) external onlyOwner {
        if(_status == Status.Open) {
            cnt = IAdamNFT(nft).lastId();
            _distribute(address(0), address(this).balance);
            closeTime = block.timestamp.add(MaxTime);
            emit Open();
        } else if(_status == Status.Close) {
            emit Close();
        }
    }

    function _distribute(address token, uint amount) internal {
        uint shareAmount = amount.mul(5).div(cnt).div(6);
        shareRewards[token] = shareRewards[token].add(shareAmount);
        grandRewards[token] = grandRewards[token].add(amount.sub(shareAmount).div(GrandIds));
        emit AddReward(token, amount);
    }

    function notify(address to, uint tokenId) external {
        if(status == Status.Open && block.timestamp <= closeTime) {
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

    function claim(address[] memory tokens) external {
         
    }

    function addReward(address token, uint amount) payable external onlyOwner {
        if(token == address(0)) {
            require(msg.value == amount, "Invalid value");
        }

        _distribute(token, amount);
    }
}
