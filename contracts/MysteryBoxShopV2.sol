// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IERC721.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IElemonNFT.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Runnable.sol";

contract MysteryBoxShopV2 is ReentrancyGuard, Runnable{
    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public _recepientAddress;

    IElemonNFT public _mysteryBoxNFT;

    uint256 public _startTime;
    uint256 public _price;
    uint256 public _boxToSell;
    uint256 public _purchasedBox;
    uint256 public _boxsPerUser;

    mapping(address => uint256) public _userBoxCounts;

    IERC20 public _elmonToken;

    constructor(){
        _mysteryBoxNFT = IElemonNFT(0x845678d1C69670090DB14965094bBAE8110486c5);
        _recepientAddress = 0x60294C21d6aAFB622B803C172641164A0958515E;        
        _elmonToken = IERC20(0xE3233fdb23F1c27aB37Bd66A19a1f1762fCf5f3F);

        _boxToSell = 6666;                  //6K6 box to sell
        _startTime = 1638192600;            //Real time
        _price = 350000000000000000000;     //350 ELMON
        _boxsPerUser = 1;
    }

    function paw24nao2f() external nonReentrant whenRunning {
        require(_startTime <= block.timestamp, "Box sale has not started");
        require(_purchasedBox < _boxToSell, "Sold out");
        require(_userBoxCounts[_msgSender()] < _boxsPerUser, "Reach limited box");

        //Get user token and process
        //50% will be burned
        uint256 burnQuantity = _price / 2;
        require(_elmonToken.transferFrom(_msgSender(), BURN_ADDRESS, burnQuantity), "Can not transfer to burn ELMON");
        //50% wil be sent back to fund
        require(_elmonToken.transferFrom(_msgSender(), _recepientAddress, burnQuantity), "Can not transfer ELMON");

        //Mint NFT
        uint256 mysteryBoxTokenId = _mysteryBoxNFT.mint(_msgSender());

        _purchasedBox++;
        _userBoxCounts[_msgSender()]++;

        emit Purchased(_msgSender(), mysteryBoxTokenId, _price, block.timestamp);
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

    function setElmonToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elmonToken = IERC20(newAddress);
    }

    function setBoxPerUser(uint256 boxPerUser) external onlyOwner{
        require(boxPerUser > 0, "boxPerUser is 0");
        _boxsPerUser = boxPerUser;
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