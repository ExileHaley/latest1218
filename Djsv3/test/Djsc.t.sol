// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {Djsc} from "../src/Djsc.sol";

contract DjscTest is Test{
    Djsc    public djsc;
    address public technology;
    address public foundation;
    address public marketingForDjsc;
    address public pot;
    address public sellFee;

    address public USDT;
    address public uniswapV2Router;
    address user;
    uint256 mainnetFork;
    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);
        USDT = address(0x55d398326f99059fF775485246999027B3197955);
        uniswapV2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        technology = address(1);
        foundation = address(2);
        marketingForDjsc = address(3);
        pot = address(4);

        sellFee = address(5);
        user = address(6);

        address[4] memory addrs = [technology, foundation, marketingForDjsc, pot];
        djsc = new Djsc(addrs, sellFee, address(0), USDT);

        addLiquidity_allowlist();
    }


    function addLiquidity_allowlist() internal{
        vm.startPrank(pot);
        deal(USDT, pot, 10000e18);

        djsc.approve(uniswapV2Router, 10000e18);
        IERC20(USDT).approve(uniswapV2Router, 10000e18);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            address(djsc), 
            USDT, 
            10000e18, 
            10000e18, 
            0, 
            0, 
            pot, 
            block.timestamp + 10
        );

        vm.stopPrank();
        assertEq(djsc.balanceOf(djsc.pancakePair()), 10000e18);
    }


    function test_sell() public {
        vm.startPrank(pot);
        djsc.transfer(user, 100e18);
        vm.stopPrank();

        uint256 beforeSwapUsdtOfSellFee = IERC20(USDT).balanceOf(sellFee);
        vm.startPrank(user);
        djsc.approve(uniswapV2Router, 100e18);
        address[] memory path = new address[](2);
        path[0] = address(djsc);
        path[1] = USDT;
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100e18, 
            0, 
            path, 
            user, 
            block.timestamp + 30
        );
        vm.stopPrank();
        uint256 afterSwapUsdtOfSellFee = IERC20(USDT).balanceOf(sellFee);
        console.log("Before:", beforeSwapUsdtOfSellFee);
        console.log("After:",afterSwapUsdtOfSellFee);
    }
}