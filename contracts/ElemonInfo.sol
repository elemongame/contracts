//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import './utils/Ownable.sol';

contract ElemonInfo is Ownable {
    struct Info{
        uint256 rarity;
        uint256 baseCardId;
        uint256 bodyPart01;
        uint256 bodyPart02;
        uint256 bodyPart03;
        uint256 bodyPart04;
        uint256 bodyPart05;
        uint256 bodyPart06;
        uint256 quality;
    }

    mapping(uint256 => Info) public _tokenInfos;

    function setInfo(uint256 tokenId, uint256 rarity, uint256 baseCardId,
        uint256 bodyPart01, uint256 bodyPart02, uint256 bodyPart03, uint256 bodyPart04,
        uint256 bodyPart05, uint256 bodyPart06, uint256 quality) external onlyOwner{
            Info memory info = Info({
                rarity: rarity,
                baseCardId: baseCardId,
                bodyPart01: bodyPart01,
                bodyPart02: bodyPart02,
                bodyPart03: bodyPart03,
                bodyPart04: bodyPart04,
                bodyPart05: bodyPart05,
                bodyPart06: bodyPart06,
                quality: quality
            });
            _tokenInfos[tokenId] = info;
            emit ElemonInfoUpdated(tokenId, info);
    }

    event ElemonInfoUpdated(uint256 tokenId, Info info);
}