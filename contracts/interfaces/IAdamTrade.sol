//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAdamTrade {
    function notify(address to, uint tokenId) external;
}