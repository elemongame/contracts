// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "./utils/Runnable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Receiver.sol";

contract MysteryBoxStaking is Runnable, ReentrancyGuard, IERC721Receiver {
    // Whether it is initialized
    bool public isInitialized;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when CAKE mining ends.
    uint256 public bonusEndBlock;

    // The block number when CAKE mining starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastRewardBlock;

    // CAKE tokens created per block.
    uint256 public rewardPerBlock;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The reward token
    IERC20Metadata public rewardToken;

    uint256 public _totalStaked;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    mapping(address => mapping(uint256 => bool)) public _userTokens;

    IERC721 public _mysteryBoxNft;

    struct UserInfo {
        uint256 stakedAmount;       // How many staked tokens the user has provided
        uint256 rewardDebt;         // Reward debt,
        uint256 lastStakingTime;
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        IERC721 mysteryBoxNft, 
        IERC20Metadata _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock){
        require(!isInitialized, "Already initialized");

        _mysteryBoxNft = mysteryBoxNft;

        // Make this contract initialized
        isInitialized = true;

        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30) - decimalsRewardToken));

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;
    }

    function deposit(uint256[] memory tokenIds) external nonReentrant whenRunning {
        uint256 tokenIdLength = tokenIds.length;
        require(tokenIdLength > 0, "TokenIds parameter is empty");
        UserInfo storage user = userInfo[_msgSender()];

        _updatePool();

        if (user.stakedAmount > 0) {
            uint256 pending = user.stakedAmount * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt;
            if (pending > 0) {
                require(rewardToken.transfer(address(_msgSender()), pending), "Can not transfer reward");
            }
        }

        for(uint256 index = 0; index < tokenIdLength; index++){
            uint256 tokenId = tokenIds[index];
            _mysteryBoxNft.safeTransferFrom(_msgSender(), address(this), tokenId);
            
            //Mark _msgSender is owner of this tokenId
            _userTokens[_msgSender()][tokenId] = true;

            emit Deposit(_msgSender(), tokenId);
        }

        user.stakedAmount += tokenIdLength;
        _totalStaked += tokenIdLength;

        user.rewardDebt = user.stakedAmount * accTokenPerShare / PRECISION_FACTOR;
        user.lastStakingTime = block.timestamp;
    }

    function withdraw(uint256[] memory tokenIds) external nonReentrant {
        UserInfo storage user = userInfo[_msgSender()];
        uint256 tokenIdLength = tokenIds.length;
        require(user.stakedAmount >= tokenIdLength, "Amount to withdraw too high");

        _updatePool();

        uint256 pending = user.stakedAmount * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt;

        if (tokenIds.length > 0) {
            for(uint256 index = 0; index < tokenIdLength; index++){
                uint256 tokenId = tokenIds[index];
                require(_userTokens[_msgSender()][tokenId], "User does not owner this token");

                _mysteryBoxNft.safeTransferFrom(address(this), _msgSender(), tokenId);
                _userTokens[_msgSender()][tokenId] = false;

                emit Withdraw(_msgSender(), tokenId);
            }

            user.stakedAmount -= tokenIdLength;
            _totalStaked -= tokenIdLength;
        }

        if (pending > 0) {
            require(rewardToken.transfer(address(_msgSender()), pending), "Can not transfer reward token");
        }

        user.rewardDebt = user.stakedAmount * accTokenPerShare / PRECISION_FACTOR;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(IERC20(_tokenAddress).transfer(address(_msgSender()), _tokenAmount), "Can not transfer token");
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    function setMysteryBoxNft(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _mysteryBoxNft = IERC721(newAddress);
    }

    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        rewardPerBlock = _rewardPerBlock;
        emit NewRewardPerBlock(_rewardPerBlock);
    }

    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _bonusEndBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(_startBlock < _bonusEndBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    function pendingReward(address _user) external view returns (uint256) {
        if(_totalStaked == 0)
            return 0;
        UserInfo storage user = userInfo[_user];
        if (block.number > lastRewardBlock && _totalStaked != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 earnedTokenReward = multiplier * rewardPerBlock;
            uint256 adjustedTokenPerShare =
                accTokenPerShare + (earnedTokenReward * PRECISION_FACTOR / _totalStaked);
            return user.stakedAmount * adjustedTokenPerShare / PRECISION_FACTOR - user.rewardDebt;
        } else {
            return user.stakedAmount * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt;
        }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (_totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 earnedTokenReward = multiplier * rewardPerBlock;
        accTokenPerShare = accTokenPerShare + earnedTokenReward * PRECISION_FACTOR / _totalStaked;
        lastRewardBlock = block.number;
    }

    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to - _from;
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock - _from;
        }
    }

    // function _getBonusAmount(uint256 amount, uint256 percent) internal pure returns(uint256){
    //     return amount * percent / 100 / 1000;
    // }
}