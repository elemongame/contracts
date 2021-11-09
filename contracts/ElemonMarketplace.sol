//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./utils/Ownable.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Runnable.sol";

contract ElemonMarketplace is Runnable, ReentrancyGuard, IERC721Receiver{
    struct MarketHistory{
        address buyer;
        address seller;
        uint256 price;
        uint256 time;
    }

    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    address public _elemonTokenAddress;
    address public _elemonNftAddress;
    address public _feeRecepientAddress;
    
    uint256 private _burningFeePercent;       //Multipled by 1000
    uint256 private _ecoFeePercent;       //Multipled by 1000
    uint256 constant public MULTIPLIER = 1000;
    
    //Mapping between tokenId and token price
    mapping(uint256 => uint256) internal _tokenPrices;
    
    //Mapping between tokenId and owner of tokenId
    mapping(uint256 => address) internal _tokenOwners;
    
    constructor(address tokenAddress, address nftAddress){
        require(tokenAddress != address(0), "Address 0");
        require(nftAddress != address(0), "Address 0");
        _elemonTokenAddress = tokenAddress;
        _elemonNftAddress = nftAddress;
        _feeRecepientAddress = _msgSender();
        _burningFeePercent = 2000;        //2%
        _ecoFeePercent = 2000;        //2%
    }
    
    /**
     * @dev Create a sell order to sell ELEMON
     * User transfer his NFT to contract to create selling order
     * Event is used to retreive logs and histories
     */
    function createSellOrder(uint256 tokenId, uint256 price) external whenRunning nonReentrant returns(bool){
        //Validate
        require(_tokenOwners[tokenId] == address(0), "Can not create sell order for this token");
        IERC721 elemonContract = IERC721(_elemonNftAddress);
        require(elemonContract.ownerOf(tokenId) == _msgSender(), "You have no permission to create sell order for this token");
        
        //Transfer Elemon NFT to contract
        elemonContract.safeTransferFrom(_msgSender(), address(this), tokenId);
        
        _tokenOwners[tokenId] = _msgSender();
        _tokenPrices[tokenId] = price;
        
        emit NewSellOrderCreated(_msgSender(), tokenId, price, _now());
        
        return true;
    }
    
    /**
     * @dev User that created selling order cancels that order
     * Event is used to retreive logs and histories
     */ 
    function cancelSellOrder(uint256 tokenId) external nonReentrant returns(bool){
        require(_tokenOwners[tokenId] == _msgSender(), "Forbidden to cancel sell order");

        IERC721 elemonContract = IERC721(_elemonNftAddress);

        //Transfer Elemon NFT from contract to sender
        elemonContract.safeTransferFrom(address(this), _msgSender(), tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;
        
        emit SellingOrderCanceled(tokenId, _now());
        
        return true;
    }
    
    /**
     * @dev Get token info about price and owner
     */ 
    function getTokenInfo(uint256 tokenId) external view returns(address, uint){
        return (_tokenOwners[tokenId], _tokenPrices[tokenId]);
    }
    
    /**
     * @dev Get purchase fee percent, this fee is for seller
     */ 
    function getFeePercent() external view returns(uint256 burningFeePercent, uint256 ecoFeePercent){
        burningFeePercent = _burningFeePercent;
        ecoFeePercent = _ecoFeePercent;
    }
    
    /**
     * @dev Get token price
     */ 
    function getTokenPrice(uint256 tokenId) external view returns(uint256){
        return _tokenPrices[tokenId];
    }
    
    /**
     * @dev Get token's owner
     */ 
    function getTokenOwner(uint256 tokenId) external view returns(address){
        return _tokenOwners[tokenId];
    }
    
    function purchase(uint256 tokenId) external whenRunning nonReentrant returns(uint256){
        address tokenOwner = _tokenOwners[tokenId];
        require(tokenOwner != address(0),"Token has not been added");
        
        uint256 tokenPrice = _tokenPrices[tokenId];
        uint256 ownerReceived = tokenPrice;
        if(tokenPrice > 0){
            IERC20 elemonTokenContract = IERC20(_elemonTokenAddress);    
            require(elemonTokenContract.transferFrom(_msgSender(), address(this), tokenPrice));
            uint256 feeAmount = 0;
            if(_burningFeePercent > 0){
                feeAmount = tokenPrice * _burningFeePercent / 100 / MULTIPLIER;
                if(feeAmount > 0){
                    require(elemonTokenContract.transfer(BURN_ADDRESS, feeAmount), "Fail to transfer fee to address(0)");
                    ownerReceived -= feeAmount;
                }
            }
            if(_ecoFeePercent > 0){
                feeAmount = tokenPrice * _ecoFeePercent / 100 / MULTIPLIER;
                if(feeAmount > 0){
                    require(elemonTokenContract.transfer(_feeRecepientAddress, feeAmount), "Fail to transfer fee to eco address");
                    ownerReceived -= feeAmount;
                }
            }
            require(elemonTokenContract.transfer(tokenOwner, ownerReceived), "Fail to transfer token to owner");
        }
        
        //Transfer Elemon NFT from contract to sender
        IERC721(_elemonNftAddress).transferFrom(address(this), _msgSender(), tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;
        
        emit Purchased(_msgSender(), tokenOwner, tokenId, tokenPrice, _now());
        
        return tokenPrice;
    }

    function setFeeRecepientAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _feeRecepientAddress = newAddress;
    }
    
    /**
     * @dev Set ELEMON contract address 
     */
    function setElemonNftAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonNftAddress = newAddress;
    }
    
    /**
     * @dev Set ELEMON token address 
     */
    function setElemonTokenAddress(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonTokenAddress = newAddress;
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
    
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    
    event NewSellOrderCreated(address seller, uint256 tokenId, uint256 price, uint256 time);
    event Purchased(address buyer, address seller, uint256 tokenId, uint256 price, uint256 time);
    event SellingOrderCanceled(uint256 tokenId, uint256 time);
}