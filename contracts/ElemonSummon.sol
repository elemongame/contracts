// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IElemonInfo.sol";
import "./interfaces/IElemonNFT.sol";
import "./utils/ReentrancyGuard.sol";

contract ElemonSummon is ReentrancyGuard, VRFConsumerBase, ConfirmedOwner(msg.sender) {
    struct RequestInfo {
        uint256 tokenId;
        uint256 level;
    }

    mapping(uint256 => uint256) public _levelPrices;

    address public _paymentTokenAddress;
    address public _recepientTokenAddress;
    IElemonInfo public _elemonInfo;
    IElemonNFT public _elemonNFT;

    bytes32 public s_keyHash;
    uint256 public s_fee;

    mapping(bytes32 => RequestInfo) public _requestInfos;
    mapping(bytes32 => bool) public _requestExecuteds;
    
    //Rarity: 1,2,3,4,5
    uint256[] public _rarities = [1, 2, 3, 4, 5];
    
    //Ability to appear Rarity
    //Level -> Rarity -> Ability
    //Ability is multipled by 100
    mapping(uint256 => mapping(uint256 => uint256)) public _rarityAbilities;

    //List of base card id by rarity
    //Rarity => base card id list
    mapping(uint256 => uint256[]) public _baseCardIds;

    //Body parts
    //Rarity => Base card id => body part (1, 2, 3, 4, 5, 6) => list of body part
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256[]))) public _bodyParts;

    //Quality
    //Rarity => Base card id => list of quality
    mapping(uint256 => mapping(uint256 => uint256[])) public _qualities;

    constructor(
        address paymentTokenAddress, address recepientTokenAddress, address elemonInfoAddress, address elemonNFTAddress,
        address vrfCoordinator, address link, bytes32 keyHash, uint256 fee) VRFConsumerBase(vrfCoordinator, link){
        s_keyHash = keyHash;
        s_fee = fee;

        _paymentTokenAddress = paymentTokenAddress;
        _recepientTokenAddress = recepientTokenAddress;
        _elemonInfo = IElemonInfo(elemonInfoAddress);
        _elemonNFT = IElemonNFT(elemonNFTAddress);
    }

    function setRarityAbility(uint256 level, uint256 rarity, uint256 ability) external onlyOwner{
        require(level > 0 && rarity > 0 && ability > 999, "Invalid parameters");
        _rarityAbilities[level][rarity] = ability;
    }

    function setRarityAbilities(uint256 level, uint256[] memory rarities, uint256[] memory abilities) external onlyOwner{
        require(level > 0, "Invalid parameters");
        require(rarities.length > 0, "Rarities is invalid");
        require(rarities.length == abilities.length, "Rarities or abilities parameter is invalid");

        for(uint index = 0; index < rarities.length; index++){
            uint256 ability = abilities[index];
            require(ability > 999, "ability should be greater than 999");
            _rarityAbilities[level][rarities[index]] = ability;
        }
    }

    function setBaseCardIds(uint256 level, uint256[] memory baseCardIds) external onlyOwner{
        require(level > 0, "Level should be greater than 0");
        require(baseCardIds.length > 0, "baseCardIds should be not empty");
        _baseCardIds[level] = baseCardIds;
    }

    function setBodyPart(uint256 rarity, uint256 baseCardId, uint256 part, uint256[] memory bodyParts) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        require(part > 0 && part <= 6, "part is invalid");
        require(bodyParts.length > 0, "bodyParts should be not empty");
        _bodyParts[rarity][baseCardId][part] = bodyParts;
    }

    function setQuality(uint256 rarity, uint256 baseCardId, uint256[] memory qualities) external onlyOwner{
        require(rarity > 0, "rarity should be greater than 0");
        require(baseCardId > 0, "baseCardId should be greater than 0");
        require(qualities.length > 0, "qualities should be not empty");
        _qualities[rarity][baseCardId] = qualities;
    }

    function setPaymentTokenAddress(address paymentTokenAddress) external onlyOwner{
        require(paymentTokenAddress != address(0), "Address 0");
        _paymentTokenAddress = paymentTokenAddress;
    }

    function setRecepientTokenAddress(address recepientTokenAddress) external onlyOwner{
        require(recepientTokenAddress != address(0), "Address 0");
        _recepientTokenAddress = recepientTokenAddress;
    }

    function setElemonInfo(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elemonInfo = IElemonInfo(newAddress);
    }

    function setElemonNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Address 0");
        _elemonNFT = IElemonNFT(newAddress);
    }

    function setLevelPrice(uint256 level, uint256 price) external onlyOwner{
        require(level > 0, "Level should be greater than 0");
        _levelPrices[level] = price;
        emit LevelPriceSetted(level, price);
    }

    function open(uint256 level) external nonReentrant{
        require(level > 0, "Level should be greater than 0");
        require(_recepientTokenAddress != address(0), "Recepient address is not setted");
        uint256 price = _levelPrices[level];
        require(price > 0, "Price should be greater than 0");        
        IERC20(_paymentTokenAddress).transferFrom(_msgSender(), _recepientTokenAddress, price);

        //Mint NFT
        uint256 tokenId = _elemonNFT.mint(msg.sender);

        //Request chainlink VRF
        require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to pay fee");
        bytes32 requestId = requestRandomness(s_keyHash, s_fee);
        _requestInfos[requestId] = RequestInfo({
            tokenId: tokenId,
            level: level
        });
        
        emit Purchased(level, _msgSender(), block.timestamp);
    }

    function setKeyHash(bytes32 keyHash) public onlyOwner {
        s_keyHash = keyHash;
    }

    function setFee(uint256 fee) public onlyOwner {
        s_fee = fee;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(!_requestExecuteds[requestId], "Duplicated requestId");

        RequestInfo memory requestInfo = _requestInfos[requestId];
        require(requestInfo.tokenId > 0, "Invalid request");

        (uint256 rarity, uint256 baseCardId, uint256 bodyPart01, 
        uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04, 
        uint256 bodyPart05, uint256 bodyPart06, uint256 quality) = _processTokenProperties(requestInfo.level, randomness);

        _elemonInfo.setInfo(requestInfo.tokenId, rarity, baseCardId, bodyPart01, bodyPart02, bodyPart03, bodyPart04, bodyPart05, bodyPart06, quality);

        _requestExecuteds[requestId] = true;
        emit ElemonOpened(requestInfo.tokenId, rarity, baseCardId, bodyPart01, bodyPart02, bodyPart03, bodyPart04, bodyPart05, bodyPart06, quality);
    }
    
    function _processTokenProperties(uint256 level, uint256 number) public view
        returns(uint256 rarity, uint256 baseCardId, uint256 bodyPart01, 
                uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04, 
                uint256 bodyPart05, uint256 bodyPart06, uint256 quality){
        //Get rarity
        uint256 processValue = 0;
        for(uint256 index = 0; index < _rarities.length; index++){
            processValue += _rarityAbilities[level][_rarities[index]];
        }
        uint256 rarityNumber = number % processValue + 1;
        processValue = 0;
        for(uint256 index = 0; index < _rarities.length; index++){
            processValue += _rarityAbilities[level][_rarities[index]];
            if(rarityNumber <= processValue){
                rarity = _rarities[index];
                break;
            }
        }

        //Get base cardId
        uint256[] memory baseCardIds = _baseCardIds[rarity];
        processValue = baseCardIds.length - 1;
        baseCardId = baseCardIds[number % processValue];

        //Get body parts
        bodyPart01 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][1]);
        bodyPart02 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][2]);
        bodyPart03 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][3]);
        bodyPart04 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][4]);
        bodyPart05 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][5]);
        bodyPart06 = _getBodyPartItem(number, _bodyParts[rarity][baseCardId][6]);

        quality = _getBodyPartItem(number, _qualities[rarity][baseCardId]);
    }

    function _getBodyPartItem(uint256 number, uint256[] memory bodyParts) internal pure returns(uint256){
        uint256 maxBodyPartIndex = bodyParts.length - 1;
        return bodyParts[number % maxBodyPartIndex];
    }

    function _msgSender() internal returns(address){
        return msg.sender;
    }
    
    event LevelPriceSetted(uint256 level, uint256 price);
    event Purchased(uint256 level, address account, uint256 time);
    event ElemonOpened(uint256 tokenId, uint256 rarity, uint256 baseCardId, uint256 bodyPart01, uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04, uint256 bodyPart05, uint256 bodyPart06, uint256 quality);
}