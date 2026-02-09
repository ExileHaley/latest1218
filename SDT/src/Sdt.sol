// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";

contract Sdt is ERC20, Ownable{
    IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    address public pair0;
    address public pair1;

    constructor(address _recipient)ERC20("SDT","SDT") Ownable(msg.sender){
        _mint(_recipient, 10000000000e18);
        pair0 = IUniswapV2Factory(pancakeRouter.factory())
            .createPair(address(this), USDT);
        pair1 = IUniswapV2Factory(pancakeRouter.factory())
            .createPair(address(this), WBNB);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (
            msg.sender == address(pancakeRouter) &&
            (to == pair0 || to == pair1)
        ) {
            revert("Liquidity adding is disabled");
        }

        super._update(from, to, amount);
    }

}

