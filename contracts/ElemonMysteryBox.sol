// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IERC721.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IElemonNFT.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Runnable.sol";

contract ElemonMysteryBox is ReentrancyGuard, Runnable{
    address public _recepientAddress;

    IElemonNFT public _mysteryBoxNFT;
    uint256 public _startBlock;
    uint256 public _endBlock;
    uint256 public _price;
    uint256 public _boxToSell;
    uint256 public _purchasedBox;

    constructor(address mysteryBoxNFTAddress, address recepientAddress){
        require(mysteryBoxNFTAddress != address(0), "mysteryBoxNFTAddress is zero address");
        require(recepientAddress != address(0), "recepientAddress is zero address");

        _mysteryBoxNFT = IElemonNFT(mysteryBoxNFTAddress);
        _recepientAddress = recepientAddress;
    }

    function purchase() payable external nonReentrant whenRunning {
        require(_purchasedBox < _boxToSell, "Sold out");
        require(msg.value == _price, "BNB to pay is invalid");
        require(_startBlock <= block.number && _endBlock >= block.number, "Can not purchase this time");

        //Send fund to wallet
        payable(_recepientAddress).transfer(msg.value);

        //Mint NFT
        uint256 mysteryBoxTokenId = _mysteryBoxNFT.mint(_msgSender());

        _purchasedBox++;
        
        emit Purchased(_msgSender(), mysteryBoxTokenId, _price, block.timestamp);
    }

    function setSaleInfo(
        uint256 startBlock, uint256 endBlock, uint256 price, uint256 boxToSell) external onlyOwner{
        _startBlock = startBlock;
        _endBlock = endBlock;
        _price = price;
        _boxToSell = boxToSell;

        emit SaleInfoSeted(startBlock, endBlock, price, boxToSell);
    }

    function setMysteryBoxNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _mysteryBoxNFT = IElemonNFT(newAddress);
    }

    function setRecepientTokenAddress(address recepientAddress) external onlyOwner{
        require(recepientAddress != address(0), "Address 0");
        _recepientAddress = recepientAddress;
    }

    function withdrawToken(address tokenAddress, address recepient, uint256 value) external onlyOwner {
        IERC20(tokenAddress).transfer(recepient, value);
    }

    event SaleInfoSeted(uint256 startBlock, uint256 endBlock, uint256 price, uint256 boxToSell);
    event Purchased(address account, uint256 tokenId, uint256 price, uint256 time);
}