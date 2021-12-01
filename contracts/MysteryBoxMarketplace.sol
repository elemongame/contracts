//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";

contract MysteryBoxMarketplace is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IERC721Receiver{
    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    IERC20 public _elmonToken;
    IERC721 public _nft;

    address public _feeRecepientAddress;
    
    uint256 private _burningFeePercent;       //Multipled by 1000
    uint256 private _ecoFeePercent;       //Multipled by 1000
    uint256 constant public MULTIPLIER = 1000;
    
    //Mapping between tokenId and token price
    mapping(uint256 => uint256) public _tokenPrices;
    
    //Mapping between tokenId and owner of tokenId
    mapping(uint256 => address) public _tokenOwners;

    //Store the latest time that token was withdrawn from contract
    mapping(uint256 => uint256) public _tokenTimes;

    uint256 public _coolDownDuration;

    function initialize(address tokenAddress, address nftAddress, address feeRecepientAddress) public initializer {
        require(tokenAddress != address(0), "Address 0");
        require(nftAddress != address(0), "Address 0");

        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        
        _elmonToken = IERC20(tokenAddress);
        _nft = IERC721(nftAddress);
        _feeRecepientAddress = feeRecepientAddress;
        _burningFeePercent = 2000;              //2%
        _ecoFeePercent = 2000;                  //2%
        _coolDownDuration = 30;             //30 seconds

        _pause();

        emit OwnershipTransferred(address(0), _msgSender());
    }
    
    /**
     * @dev Create a sell order to sell ELEMON
     * User transfer his NFT to contract to create selling order
     * Event is used to retreive logs and histories
     */
    function createSellOrder(uint256 tokenId, uint256 price) external whenNotPaused nonReentrant returns(bool){
        require(price > 0, "Price should be greater than 0");
        require(_tokenOwners[tokenId] == address(0), "Can not create sell order for this token");
        require(_nft.ownerOf(tokenId) == _msgSender(), "You have no permission to create sell order for this token");
        require(_tokenTimes[tokenId] + _coolDownDuration <= block.timestamp, "Cool down time");
        
        //Transfer Elemon NFT to contract
        _nft.safeTransferFrom(_msgSender(), address(this), tokenId);
        
        _tokenOwners[tokenId] = _msgSender();
        _tokenPrices[tokenId] = price;
        
        emit NewSellOrderCreated(_msgSender(), tokenId, price, block.timestamp);
        
        return true;
    }
    
    /**
     * @dev User that created selling order cancels that order
     * Event is used to retreive logs and histories
     */ 
    function cancelSellOrder(uint256 tokenId) external nonReentrant returns(bool){
        require(_tokenOwners[tokenId] == _msgSender(), "Forbidden to cancel sell order");

        //Transfer Elemon NFT from contract to sender
        _nft.safeTransferFrom(address(this), _msgSender(), tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;

        _tokenTimes[tokenId] = block.timestamp;
        
        emit SellingOrderCanceled(tokenId, block.timestamp);
        
        return true;
    }

    function manualCancelSellingOrder(uint256 tokenId) external nonReentrant onlyOwner returns(bool){
        require(_tokenOwners[tokenId] != address(0), "Token does not exist on market");

        //Transfer Elemon NFT from contract to sender
        _nft.safeTransferFrom(address(this), _tokenOwners[tokenId], tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;
        _tokenTimes[tokenId] = block.timestamp;
        
        emit SellingOrderCanceled(tokenId, block.timestamp);
        
        return true;
    }
    
    /**
     * @dev Get token info about price and owner
     */ 
    function getTokenInfo(uint256 tokenId) external view returns(address, uint256){
        return (_tokenOwners[tokenId], _tokenPrices[tokenId]);
    }
    
    /**
     * @dev Get purchase fee percent, this fee is for seller
     */ 
    function getFeePercent() external view returns(uint256 burningFeePercent, uint256 ecoFeePercent){
        burningFeePercent = _burningFeePercent;
        ecoFeePercent = _ecoFeePercent;
    }
    
    function purchase(uint256 tokenId, uint256 requestPrice) external whenNotPaused nonReentrant returns(uint256){
        address tokenOwner = _tokenOwners[tokenId];
        require(tokenOwner != address(0),"Token has not been added");
        
        uint256 tokenPrice = _tokenPrices[tokenId];
        require(requestPrice == tokenPrice, "Invalid request price");

        uint256 ownerReceived = tokenPrice;
        if(tokenPrice > 0){
            uint256 feeAmount = 0;
            if(_burningFeePercent > 0){
                feeAmount = tokenPrice * _burningFeePercent / 100 / MULTIPLIER;
                if(feeAmount > 0){
                    require(_elmonToken.transferFrom(_msgSender(), BURN_ADDRESS, feeAmount), "Fail to transfer fee to address(0)");
                    ownerReceived -= feeAmount;
                }
            }
            if(_ecoFeePercent > 0){
                feeAmount = tokenPrice * _ecoFeePercent / 100 / MULTIPLIER;
                if(feeAmount > 0){
                    require(_elmonToken.transferFrom(_msgSender(), _feeRecepientAddress, feeAmount), "Fail to transfer fee to eco address");
                    ownerReceived -= feeAmount;
                }
            }
            require(_elmonToken.transferFrom(_msgSender(), tokenOwner, ownerReceived), "Fail to transfer token to owner");
        }
        
        //Transfer Elemon NFT from contract to sender
        _nft.transferFrom(address(this), _msgSender(), tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;

        _tokenTimes[tokenId] = block.timestamp;
        
        emit Purchased(_msgSender(), tokenOwner, tokenId, tokenPrice, block.timestamp);
        
        return tokenPrice;
    }

    function setCoolDownDuration(uint256 value) external onlyOwner{
        _coolDownDuration = value;
    }

    function setFeeRecepientAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _feeRecepientAddress = newAddress;
    }
    
    function setNft(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _nft = IERC721(newAddress);
    }
    
    function setElemonTokenAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elmonToken = IERC20(newAddress);
    }
    
    /**
     * @dev Get ELEMON token address 
     */
    function setFeePercent(uint256 burningFeePercent, uint256 ecoFeePercent) external onlyOwner{
        require(burningFeePercent < 100 * MULTIPLIER, "Invalid burning fee percent");
        require(ecoFeePercent < 100 * MULTIPLIER, "Invalid ecosystem fee percent");
        _burningFeePercent = burningFeePercent;
        _ecoFeePercent = ecoFeePercent;
    }

    /**
     * @dev Owner withdraws ERC20 token from contract by `tokenAddress`
     */
    function withdrawToken(address tokenAddress, address recepient) public onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recepient, token.balanceOf(address(this)));
    }

    /**
     * @dev Owner withdraws ERC20 token from contract by `tokenAddress`
     */
    function withdrawNft(uint256 tokenId, address recepient) public onlyOwner{
        _nft.safeTransferFrom(address(this), recepient, tokenId);
        emit NftWithdrawn(tokenId);
    }

    function pauseContract() external onlyOwner{
        _pause();
    }

    function unpauseContract() external onlyOwner{
        _unpause();
    }
    
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    
    event NewSellOrderCreated(address seller, uint256 tokenId, uint256 price, uint256 time);
    event Purchased(address buyer, address seller, uint256 tokenId, uint256 price, uint256 time);
    event SellingOrderCanceled(uint256 tokenId, uint256 time);
    event NftWithdrawn(uint256 tokenId);
}