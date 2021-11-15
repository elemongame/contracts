//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IERC20.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Runnable.sol";

contract TokenDistributor is Runnable, ReentrancyGuard{
    function distribute(address tokenAddress, address[] memory addresses, uint256[] memory amounts) public whenRunning nonReentrant onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        for(uint256 index = 0; index < addresses.length; index++){
            token.transfer(addresses[index], amounts[index]);
        }
    }

    function distributeWithSameQuantity(address tokenAddress, address[] memory addresses, uint256 amount) public whenRunning nonReentrant onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        for(uint256 index = 0; index < addresses.length; index++){
            token.transfer(addresses[index], amount);
        }
    }

    function withdrawToken(address tokenAddress, address recepient) public onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recepient, token.balanceOf(address(this)));
    }

    function distributeNative(address[] memory addresses, uint256 amount) payable public whenRunning nonReentrant onlyOwner{
        for(uint256 index = 0; index < addresses.length; index++){
            payable(addresses[index]).transfer(amount);
        }
    }
}