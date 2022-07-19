//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAdamNFT {
    function lastId() view external returns(uint);
    function getShare(uint) view external returns(uint, uint);
}