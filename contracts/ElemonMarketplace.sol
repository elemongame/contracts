// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";

contract ElemonMarketplace is Ownable, IERC721Receiver{
    struct MarketHistory{
        address buyer;
        address seller;
        uint256 price;
        uint256 time;
    }
    
    address public _elemonTokenAddress;
    address public _elemonNftAddress;
    
    uint256 private _feePercent;       //Multipled by 1000
    uint256 constant public MULTIPLIER = 1000;
    
    uint256[] internal _tokens;
    
    //Mapping between tokenId and token price
    mapping(uint256 => uint256) internal _tokenPrices;
    
    //Mapping between tokenId and owner of tokenId
    mapping(uint256 => address) internal _tokenOwners;
    
    mapping(uint256 => MarketHistory[]) internal _marketHistories;
    
    constructor(address tokenAddress, address nftAddress){
        _elemonTokenAddress = tokenAddress;
        _elemonNftAddress = nftAddress;
        _feePercent = 2000;        //2%
    }
    
    /**
     * @dev Create a sell order to sell ELEMON category
     */
    function createSellOrder(uint256 tokenId, uint256 price) external returns(bool){
        //Validate
        require(_tokenOwners[tokenId] == address(0), "Can not create sell order for this token");
        IERC721 elemonContract = IERC721(_elemonNftAddress);
        require(elemonContract.ownerOf(tokenId) == _msgSender(), "You have no permission to create sell order for this token");
        
        //Transfer Elemon NFT to contract
        elemonContract.safeTransferFrom(_msgSender(), address(this), tokenId);
        
        _tokenOwners[tokenId] = _msgSender();
        _tokenPrices[tokenId] = price;
        _tokens.push(tokenId);
        
        emit NewSellOrderCreated(_msgSender(), tokenId, price, _now());
        
        return true;
    }
    
    /**
     * @dev User that created sell order can cancel that order
     */ 
    function cancelSellOrder(uint256 tokenId) external returns(bool){
        require(_tokenOwners[tokenId] == _msgSender(), "Forbidden to cancel sell order");

        IERC721 elemonContract = IERC721(_elemonNftAddress);
        //Transfer Elemon NFT from contract to sender
        elemonContract.safeTransferFrom(address(this), _msgSender(), tokenId);
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;
        _tokens = _removeFromTokens(tokenId);
        
        emit SellingOrderCanceled(tokenId, _now());
        
        return true;
    }
    
    /**
     * @dev Get all active tokens that can be purchased 
     */ 
    function getTokens() external view returns(uint256[] memory){
        return _tokens;
    }
    
    /**
     * @dev Get token info about price and owner
     */ 
    function getTokenInfo(uint tokenId) external view returns(address, uint){
        return (_tokenOwners[tokenId], _tokenPrices[tokenId]);
    }
    
    /**
     * @dev Get purchase fee percent, this fee is for seller
     */ 
    function getFeePercent() external view returns(uint){
        return _feePercent;
    }
    
    function getMarketHistories(uint256 tokenId) external view returns(MarketHistory[] memory){
        return _marketHistories[tokenId];
    }
    
    /**
     * @dev Get token price
     */ 
    function getTokenPrice(uint256 tokenId) external view returns(uint){
        return _tokenPrices[tokenId];
    }
    
    /**
     * @dev Get token's owner
     */ 
    function getTokenOwner(uint256 tokenId) external view returns(address){
        return _tokenOwners[tokenId];
    }
    
    /**
     * @dev User purchases a ELEMON category
     */ 
    function purchase(uint tokenId) external returns(uint){
        address tokenOwner = _tokenOwners[tokenId];
        require(tokenOwner != address(0),"Token has not been added");
        
        uint256 tokenPrice = _tokenPrices[tokenId];
        
        if(tokenPrice > 0){
            IERC20 elemonTokenContract = IERC20(_elemonTokenAddress);    
            require(elemonTokenContract.transferFrom(_msgSender(), address(this), tokenPrice));
            uint256 feeAmount = 0;
            if(_feePercent > 0){
                feeAmount = tokenPrice * _feePercent / 100 / MULTIPLIER;
                require(elemonTokenContract.transfer(owner(), feeAmount));
            }
            require(elemonTokenContract.transfer(tokenOwner, tokenPrice - feeAmount));
        }
        
        //Transfer Elemon NFT from contract to sender
        IERC721(_elemonNftAddress).transferFrom(address(this),_msgSender(), tokenId);
        
        _marketHistories[tokenId].push(MarketHistory({
            buyer: _msgSender(),
            seller: _tokenOwners[tokenId],
            price: tokenPrice,
            time: block.timestamp
        }));
        
        _tokenOwners[tokenId] = address(0);
        _tokenPrices[tokenId] = 0;
        _tokens = _removeFromTokens(tokenId);
        
        emit Purchased(_msgSender(), tokenId, tokenPrice, _now());
        
        return tokenPrice;
    }
    
    /**
     * @dev Set ELEMON contract address 
     */
    function setElemonContractAddress(address newAddress) external onlyOwner{
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
    function setFeePercent(uint feePercent) external onlyOwner{
        _feePercent = feePercent;
    }
    
    /**
     * @dev Remove token item by value from _tokens and returns new list _tokens
     */ 
    function _removeFromTokens(uint tokenId) internal view returns(uint256[] memory){
        uint256 tokenCount = _tokens.length;
        uint256[] memory result = new uint256[](tokenCount-1);
        uint256 resultIndex = 0;
        for(uint tokenIndex = 0; tokenIndex < tokenCount; tokenIndex++){
            uint tokenItemId = _tokens[tokenIndex];
            if(tokenItemId != tokenId){
                result[resultIndex] = tokenItemId;
                resultIndex++;
            }
        }
        
        return result;
    }
    
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    
    event NewSellOrderCreated(address seller, uint256 tokenId, uint256 price, uint256 time);
    event Purchased(address buyer, uint256 tokenId, uint256 price, uint256 time);
    event SellingOrderCanceled(uint256 tokenId, uint256 time);
}