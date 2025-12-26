// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Gas is ERC20, Ownable{

    address public x101;

    modifier onlyBurn() {
        require(x101 == msg.sender, "Not permit");
        _;
    }

    constructor(address _initialRecipient)ERC20("Gas","GAS")Ownable(msg.sender){
        _mint(_initialRecipient, 3030000e18);
    }

    function setX101Addr(address _x101) external onlyOwner{
        require(_x101 != address(0),"Error addr.");
        x101 = _x101;
    }

    function mint(address to, uint256 amount) external onlyOwner{
        require(to != address(0), "Error addr.");
        _mint(to, amount);
    }

    function specificBurn(address account, address to, uint256 amount) external onlyBurn{
        _update(account, to, amount);
    }
    
}