// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Tdjs is ERC20, Ownable{
    constructor(address _initialRecipient)ERC20("TDJS","TDJS")Ownable(msg.sender){
        _mint(_initialRecipient, 1000000e18);
    }
}