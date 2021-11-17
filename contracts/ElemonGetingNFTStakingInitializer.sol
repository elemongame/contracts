// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "./utils/Runnable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IElemonNFT.sol";
import "./interfaces/IElemonInfo.sol";

contract ElemonGetingNFTStakingInitializer is Runnable, ReentrancyGuard {
    struct UserInfo {
        uint256 stakedAmount;
        uint256 lastStakingTime;
        uint256 elemonTokenId;
    }

    IERC20 public _elemonToken;
    IElemonInfo public _elemonInfo;
    IElemonNFT public _elemonNFT;

    uint256 public _rarity;
    uint256 public _minStakingQuantity;
    uint256 public _stakingDuration;

    uint256 public _startTime;
    uint256 public _endTime;

    mapping(address => UserInfo) public _userInfos;

    function initialize(
        address elemonTokenddress, 
        address elemonNftAddress, 
        address elemonInfoAddress, 
        uint256 rarity, 
        uint256 minStakingQuantity, 
        uint256 stakingDuration,
        uint256 startTime,
        uint256 endTime) external {
            require(_stakingDuration > 0, "Invalid _stakingDuration");
            require(elemonTokenddress != address(0), "elemonTokenddress is zero address");
            require(elemonNftAddress != address(0), "elemonNftAddress is zero address");
            require(elemonInfoAddress != address(0), "elemonInfoAddress is zero address");

            _elemonToken = IERC20(elemonTokenddress);
            _elemonInfo = IElemonInfo(elemonInfoAddress);
            _elemonNFT = IElemonNFT(elemonNftAddress);
            _rarity = rarity;
            _minStakingQuantity = minStakingQuantity;
            _stakingDuration = stakingDuration;
            _startTime = startTime;
            _endTime = endTime;
    }

    function stake(uint256 amount) external nonReentrant whenRunning{
        require(amount > 0, "Amount should be greater than 0");
        require(_startTime <= block.timestamp && block.timestamp <= _endTime, "Can not stake at this time");

        UserInfo storage userInfo = _userInfos[_msgSender()];
        require(userInfo.stakedAmount + amount >= _minStakingQuantity, "Invalid for min staking quantity");

        require(_elemonToken.transferFrom(_msgSender(), address(this), amount), "Can not transfer token");

        userInfo.stakedAmount += amount;
        userInfo.lastStakingTime = block.timestamp;
        emit Staked(_msgSender(), amount, block.timestamp);
    }

    function withdraw(uint256 amount) external nonReentrant whenRunning{
        require(amount > 0, "Amount should be greater than 0");

        UserInfo storage userInfo = _userInfos[_msgSender()];
        require(userInfo.stakedAmount >= amount, "Amount is invalid");

        require(_elemonToken.transfer(_msgSender(), amount), "Can not transfer token");
        
        if(userInfo.elemonTokenId == 0 && userInfo.lastStakingTime + _stakingDuration <= block.timestamp){
            //Mint Elemon for user
           userInfo.elemonTokenId = _elemonNFT.mint(_msgSender());

           //Set Elemon info with rarity
           _elemonInfo.setRarity(userInfo.elemonTokenId, _rarity);

           emit ElemonDistributed(_msgSender(), userInfo.elemonTokenId);
        }

        userInfo.stakedAmount -= amount;
        emit Withdrawn(_msgSender(), amount, block.timestamp);
    }

    function setMinStakingQuantity(uint256 quantity) external onlyOwner{
        require(quantity > 0, "Quantity should be greater than 0");
        _minStakingQuantity = quantity;
    }

    function setRarity(uint256 rarity) external onlyOwner{
        require(rarity > 0, "Rarity should be greater than 0");
        _rarity = rarity;
    }

    function setTime(uint256 startTime, uint256 endTime) external onlyOwner{
        require(startTime < endTime, "Start time should be less than end time");
        _startTime = startTime;
        _endTime = endTime;
    }

    function setDuration(uint256 duration) external onlyOwner{
        require(duration > 0, "Zero address");
        _stakingDuration = duration;
    }
    
    function setElemonToken(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonToken = IERC20(newAddress);
    }

    function setElemonNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonNFT = IElemonNFT(newAddress);
    }

    function setElemonInfo(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonInfo = IElemonInfo(newAddress);
    }

    event Staked(address account, uint256 amount, uint256 time);
    event Withdrawn(address acocunt, uint256 amount, uint256 time);
    event ElemonDistributed(address account, uint256 tokenId);
}