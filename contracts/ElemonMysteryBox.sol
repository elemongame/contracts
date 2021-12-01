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

    uint256 public _startTime;
    uint256 public _price;
    uint256 public _boxToSell;
    uint256 public _purchasedBox;

    uint256 public _boxsPerUser;
    uint256 public _minConditionElmon;

    mapping(address => uint256) public _userBoxCounts;

    IERC20 public _busdToken;
    IERC20 public _elmonToken;

    constructor(
        address mysteryBoxNFTAddress, address recepientAddress,
        address elmonTokenAddress, address busdTokenAddress){
        require(mysteryBoxNFTAddress != address(0), "mysteryBoxNFTAddress is zero address");
        require(recepientAddress != address(0), "recepientAddress is zero address");
        require(elmonTokenAddress != address(0), "elmonTokenAddress is zero address");
        require(busdTokenAddress != address(0), "busdTokenAddress is zero address");

        _mysteryBoxNFT = IElemonNFT(mysteryBoxNFTAddress);
        _recepientAddress = recepientAddress;
        _busdToken = IERC20(busdTokenAddress);
        _elmonToken = IERC20(elmonTokenAddress);

        _boxToSell = 20000;     //20K box to sell
        _startTime = 1637676000;         //Real time
        _price = 300000000000000000000;

        _boxsPerUser = 5;
        _minConditionElmon = 500000000000000000000;
    }

    function purchase(uint256 quantity) external nonReentrant whenRunning {
        require(quantity > 0, "Quantity is 0");
        require(_startTime <= block.timestamp, "Can not purchase this time");
        require(_purchasedBox + quantity <= _boxToSell, "Sold out");

        require(_userBoxCounts[_msgSender()]  + quantity <= _boxsPerUser, "Reach limited box");
        require(_elmonToken.balanceOf(_msgSender()) >= _minConditionElmon, "Hoding ELMON is not enough");

        uint256 totalPrice = _price * quantity;

        //Send fund to wallet
        require(_busdToken.transferFrom(_msgSender(), _recepientAddress, totalPrice), "Can not transfer BUSD");

        for(uint256 index = 0; index < quantity; index++){
            //Mint NFT
            uint256 mysteryBoxTokenId = _mysteryBoxNFT.mint(_msgSender());
        
            emit Purchased(_msgSender(), mysteryBoxTokenId, _price, block.timestamp);
        }

        _purchasedBox += quantity;
        _userBoxCounts[_msgSender()] += quantity;
    }

    function setSaleInfo(uint256 startTime, uint256 price, uint256 boxToSell) external onlyOwner{
        _startTime = startTime;
        _price = price;
        _boxToSell = boxToSell;

        emit SaleInfoSeted(startTime, price, boxToSell);
    }

    function setMysteryBoxNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _mysteryBoxNFT = IElemonNFT(newAddress);
    }

    function setBusdToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _busdToken = IERC20(newAddress);
    }

    function setElmonToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elmonToken = IERC20(newAddress);
    }

    function setBoxPerUser(uint256 boxPerUser) external onlyOwner{
        require(boxPerUser > 0, "boxPerUser is 0");
        _boxsPerUser = boxPerUser;
    }

    function setMinConditionElmon(uint256 value) external onlyOwner{
        _minConditionElmon = value;
    }

    function setRecepientTokenAddress(address recepientAddress) external onlyOwner{
        require(recepientAddress != address(0), "Address 0");
        _recepientAddress = recepientAddress;
    }

    function withdrawToken(address tokenAddress, address recepient, uint256 value) external onlyOwner {
        IERC20(tokenAddress).transfer(recepient, value);
    }

    event SaleInfoSeted(uint256 startTime, uint256 price, uint256 boxToSell);
    event Purchased(address account, uint256 tokenId, uint256 price, uint256 time);
}