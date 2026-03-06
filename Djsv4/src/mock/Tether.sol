// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Tether is ERC20, Ownable{
    address public constant TEST = 0x300b1B817F2431e345Cde7b80229016F86ED5984;
    constructor(address _initialRecipient)ERC20("TEST-USD","TUS")Ownable(msg.sender){
        _mint(_initialRecipient, 1000000000000e18);
        _mint(TEST, 10000e18);
    }

}