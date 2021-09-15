pragma solidity 0.8.7;

import './ERC20.sol';

contract ElemonToken is ERC20 {
    constructor() ERC20("Elemon Token", "EMON", 500000000000000000000000000){}
}

// SPDX-License-Identifier: MIT