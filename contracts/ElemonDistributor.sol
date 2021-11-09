//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IERC20.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Runnable.sol";

contract ElemonDistributor is Runnable, ReentrancyGuard{
    IERC20 public _elemonToken;
    
    constructor(address tokenAddress){
        _elemonToken = IERC20(tokenAddress);
    }
    
    function setElemonTokenAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonToken = IERC20(newAddress);
    }

    function transferToken(address[] memory addresses, uint256[] memory amounts) public whenRunning nonReentrant onlyOwner{
        require(addresses.length == amounts.length, "Invalid input");
        for(uint256 index = 0; index < addresses.length; index++){
            _elemonToken.transfer(addresses[index], amounts[index]);
        }
    }

    function withdrawToken(address tokenAddress, address recepient) public onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recepient, token.balanceOf(address(this)));
    }
}