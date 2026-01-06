// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Gas is ERC20, Ownable{

    constructor()ERC20("Gas","GAS")Ownable(msg.sender){}

    function mint(address to, uint256 amount) external onlyOwner{
        require(to != address(0), "Error addr.");
        _mint(to, amount);
    }
    
}