// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Receiver.sol";
import "./utils/Runnable.sol";

interface IElemonNFT{
    function mint(address to, uint256 tokenId) external;
    function setContractOwner(address newOwner) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract ElemonShop is Runnable, IERC721Receiver{
    IElemonNFT public _elemonNft;
    
    //Mapping tokenId and 
    mapping(uint256 => bool) public _isSold;
    
    //Mapping star => price
    mapping(uint256 => uint256) public _starPrices;
    
    //Mapping tokenId => star
    mapping(uint256 => uint256) public _tokenStars;
    
    constructor(address nftAddress){
        _elemonNft = IElemonNFT(nftAddress);
    }
    
    function setElemonNft(address newAddress) public onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elemonNft = IElemonNFT(newAddress);
    }
    
    function setStarPrice(uint256 star, uint256 price) public onlyOwner{
        require(star > 0, "Star is 0");
        require(price > 0, "Price is 0");
        _starPrices[star] = price;
    }
    
    function setStarPriceMultiple(uint256[] memory stars, uint256[] memory prices) public onlyOwner{
        require(stars.length > 0 , "Empty array");
        require(stars.length == prices.length, "Invalid input");
        
        for(uint256 index = 0; index < stars.length; index++){
            require(stars[index] > 0, "Star is 0");
            require(prices[index] > 0, "Price is 0");
            _starPrices[stars[index]] = prices[index];
        }
    }
    
    function setTokenStar(uint256 tokenId, uint256 star) public onlyOwner{
        require(star > 0, "Star is 0");
        _tokenStars[tokenId] = star;
    }
    
    function setTokenStarMultiple(uint256[] memory tokenIds, uint256[] memory stars) public onlyOwner{
        require(tokenIds.length > 0 , "Empty array");
        require(tokenIds.length == stars.length, "Invalid input");
        
        for(uint256 index = 0; index < stars.length; index++){
            require(stars[index] > 0, "Star is 0");
            _tokenStars[tokenIds[index]] = stars[index];
        }
    }
    
    function getTokenPrice(uint256 tokenId) public view returns(uint256){
        return _starPrices[_tokenStars[tokenId]];
    }
    
    function purchase(uint256 tokenId) public payable whenRunning returns(bool){
        require(!_isSold[tokenId], "Sold");
        uint256 price = getTokenPrice(tokenId);
        require(price > 0, "Price is 0");
        require(msg.value == price, "Invalid BNB to purchase");
        
        _elemonNft.safeTransferFrom(address(this), _msgSender(), tokenId);
        _isSold[tokenId] = true;
        
        emit Purchased(_msgSender(), tokenId, price, _now());
        return true;
    }
    
    function withdrawToken(address tokenAddress) public onlyOwner{
        IERC20 token = IERC20(tokenAddress);
        token.transfer(owner(), token.balanceOf(address(this)));
    }
    
    function setNftContractOwner(address newOwner) public onlyOwner{
        _elemonNft.setContractOwner(newOwner);
    }
    
    function withdrawBnb() public onlyOwner{
        require(address(this).balance > 0, "Zero balance");
        payable(owner()).transfer(address(this).balance);
    }
    
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    
    event Purchased(address account, uint256 tokenId, uint256 price, uint256 time);
}