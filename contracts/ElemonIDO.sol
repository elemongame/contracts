//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import './utils/Ownable.sol';
import './utils/ReentrancyGuard.sol';
import './interfaces/IERC20.sol';

contract ElemonIDO is Ownable, ReentrancyGuard {
    IERC20 public _busdToken;
    IERC20 public _elmonToken;
    address public _idoRecepientAddress;

    //The token price for BUSD, multipled by 1000
    uint256 public constant ELEMON_PRICE = 90;      //0.09
    uint256 public constant ONE_THOUSAND = 1000;

    uint256 public _startBlock;
    uint256 public _endBlock;
    uint256[] public _claimableBlocks;
    mapping(uint256 => uint256) public _claimablePercents;

    //Store the number of token that user can buy
    //Mapping user address and the number of ELEMON user can buy
    mapping(address => uint256) public _userSlots;
    mapping(address => uint256) public _userBoughts;
    mapping(address => uint256) public _claimCounts;

    constructor(
        address busdAddress, address elmonAddress, address idoRecepientAddress,
        uint256 startBlock, uint256 endBlock){
        _busdToken = IERC20(busdAddress);
        _elmonToken = IERC20(elmonAddress);
        _idoRecepientAddress = idoRecepientAddress;
        _startBlock = startBlock;
        _endBlock = endBlock;

        //THIS PROPERTIES WILL BE SET WHEN DEPLOYING CONTRACT
        //_claimableBlocks = [];
        //_claimablePercents[] = 50;
        //_claimablePercents[] = 25;
        //_claimablePercents[] = 25;
    }

    function buy(uint256 busdQuantity) external nonReentrant {
        require(_idoRecepientAddress != address(0), "IDO recepient address has not been setted");
        require(block.number >= _startBlock && block.number <= _endBlock, "Can not buy at this time");
        require(_userSlots[_msgSender()] > 0, "You are not in whitelist");
        uint256 maxTokenCanBuy = _userSlots[_msgSender()] - _userBoughts[_msgSender()];
        require(maxTokenCanBuy > 0, "You reach to maximum to buy");
        
        uint256 tokenQuantity = busdQuantity * ONE_THOUSAND / ELEMON_PRICE;
        require(tokenQuantity > 0, "No token to buy");

        if(tokenQuantity > maxTokenCanBuy){
            tokenQuantity = maxTokenCanBuy;

            busdQuantity = tokenQuantity * ELEMON_PRICE / ONE_THOUSAND;
        }

        _busdToken.transferFrom(_msgSender(), _idoRecepientAddress , busdQuantity);
        _userBoughts[_msgSender()] += tokenQuantity;

        emit Purchased(_msgSender(), tokenQuantity);
    }

    function claim() external nonReentrant{
        uint256 userBought = _userBoughts[_msgSender()];
        require(userBought > 0, "Nothing to claim");
        require(_claimableBlocks.length > 0, "Can not claim at this time");
        require(block.number >= _claimableBlocks[0], "Can not claim at this time");

        uint256 startIndex = _claimCounts[_msgSender()];
        require(startIndex < _claimableBlocks.length, "You have claimed all token");

        uint256 tokenQuantity = 0;
        for(uint256 index = startIndex; index < _claimableBlocks.length; index++){
            uint256 claimBlock = _claimableBlocks[index];
            if(block.number >= claimBlock){
                tokenQuantity += userBought * _claimablePercents[claimBlock] / 100;
                _claimCounts[_msgSender()]++;
            }else{
                break;
            }
        }

        require(tokenQuantity > 0, "Token quantity is not enough to claim");
        _elmonToken.transfer(_msgSender(), tokenQuantity);

        emit Claimed(_msgSender(), tokenQuantity);
    }

    function getClaimable(address account) external view returns(uint256){
        uint256 userBought = _userBoughts[account];
        if(userBought == 0) return 0;
        if(_claimableBlocks.length == 0) return 0;
        if(block.number < _claimableBlocks[0]) return 0;
        if(_claimCounts[account] >= _claimableBlocks.length) return 0;

        uint256 startIndex = _claimCounts[account];

        uint256 tokenQuantity = 0;
        for(uint256 index = startIndex; index < _claimableBlocks.length; index++){
            uint256 claimBlock = _claimableBlocks[index];
            if(block.number >= claimBlock){
                tokenQuantity += userBought * _claimablePercents[claimBlock] / 100;
            }else{
                break;
            }
        }

        return tokenQuantity;
    }

    function setBusdToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _busdToken = IERC20(newAddress);
    }

    function setElmonToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elmonToken = IERC20(newAddress);
    }

    function setIdoRecepientAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _idoRecepientAddress = newAddress;
    }

    function setIdoBlocks(uint256 startBlock, uint256 endBlock) external onlyOwner{
        require(startBlock > block.number, "Start block should be greater than current block");
        require(startBlock < endBlock, "Start block should be less than end block");
        _startBlock = startBlock;
        _endBlock = endBlock;
    }

    function setClaimableBlocks(uint256[] memory blocks) external onlyOwner{
        require(blocks.length > 0, "Empty input");
        _claimableBlocks = blocks;
    }

    function setClaimablePercents(uint256[] memory blocks, uint256[] memory percents) external onlyOwner{
        require(blocks.length > 0, "Empty input");
        require(blocks.length == percents.length, "Empty input");
        for(uint256 index = 0; index < blocks.length; index++){
            _claimablePercents[blocks[index]] = percents[index];
        }
    }

    event Purchased(address account, uint256 tokenQuantity);
    event Claimed(address account, uint256 tokenQuantity);
}