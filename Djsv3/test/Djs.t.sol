// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {Djs} from "../src/Djs.sol";
import {NodeDividends} from "../src/NodeDividends.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DjsTest is Test{
    Djs     public djs;

    address public initialRecipient;
    address public sellAndProfit;
    address public walletForProfit;

    address public USDT;
    address public uniswapV2Router;
    address user;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);
        USDT = address(0x55d398326f99059fF775485246999027B3197955);
        uniswapV2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        initialRecipient = address(1);
        sellAndProfit = address(2);
        walletForProfit = address(3);

        user = address(4);

        vm.startPrank(initialRecipient);
        djs = new Djs(initialRecipient, sellAndProfit, walletForProfit, USDT);
        djs.setTradingOpen(true);
        vm.stopPrank();

        addLiquidity_allowlist();
        
    }

    function addLiquidity_allowlist() internal{
        vm.startPrank(initialRecipient);
        deal(USDT, initialRecipient, 10000e18);

        djs.approve(uniswapV2Router, 10000e18);
        IERC20(USDT).approve(uniswapV2Router, 10000e18);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            address(djs), 
            USDT, 
            10000e18, 
            10000e18, 
            0, 
            0, 
            initialRecipient, 
            block.timestamp + 10
        );

        vm.stopPrank();
        assertEq(djs.balanceOf(djs.pancakePair()), 10000e18);
    }

    function test_exchange_utils(address _user, address _fromToken, address _toToken, uint256 _fromAmount) internal{
        vm.startPrank(_user);
        IERC20(_fromToken).approve(uniswapV2Router, _fromAmount);
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _fromAmount, 
            0, 
            path, 
            _user, 
            block.timestamp + 30
        );
        vm.stopPrank();
    }


    function test_buy() public {
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);
        uint256 cost = djs.totalCostUsdt(user);
        console.log("buy cost:", cost);

        uint256 toNode = djs.balanceOf(address(djs));
        console.log("to node:",toNode);
    }

    function test_sell_no_profit() public{
        vm.startPrank(initialRecipient);
        djs.transfer(user, 100e18);
        vm.stopPrank();
        test_exchange_utils(user, address(djs), USDT, 100e18);
        assertEq(djs.balanceOf(address(djs)), 0);
    }
    
    function test_sell_normal_profit() public {
        // user buy
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);

        //user1 buy
        address user1 = address(10);
        deal(USDT, user1, 1000e18);
        test_exchange_utils(user1, USDT, address(djs), 1000e18);

        //user sell清空
        uint256 amountToSell = djs.balanceOf(user);
        test_exchange_utils(user, address(djs), USDT, amountToSell);

        //user buy
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);

        uint256 toNode0 = djs.balanceOf(address(djs));
        uint256 amountToSell0 = djs.balanceOf(user);
        test_exchange_utils(user, address(djs), USDT, amountToSell0);
        uint256 toNode1 = djs.balanceOf(address(djs));
        assertEq(toNode0, toNode1);
    }

    function test_sell_sellFee() public {
        uint256 usdtBalanceOfSellFee0 = IERC20(USDT).balanceOf(djs.sellAndProfit());
        vm.startPrank(initialRecipient);
        djs.transfer(user, 100e18);
        vm.stopPrank();

        test_exchange_utils(user, address(djs), USDT, 100e18);

        uint256 usdtBalanceOfSellFee1 = IERC20(USDT).balanceOf(djs.sellAndProfit());
        console.log("test_sell_sellFee result:", usdtBalanceOfSellFee1 - usdtBalanceOfSellFee0);
    }

    function test_profitFee_to_node() public {
        vm.startPrank(initialRecipient);
        //deploy nodeDividends
        NodeDividends nodeImpl = new NodeDividends();
        ERC1967Proxy nodeProxy = new ERC1967Proxy(
            address(nodeImpl),
            abi.encodeCall(nodeImpl.initialize,(address(0), address(0), address(djs)))
        );
        NodeDividends nodeDividends = NodeDividends(payable(address(nodeProxy)));
        djs.setNodeDividends(address(nodeDividends));
        vm.stopPrank();

        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);
        // console.log("djs balance of djs contract:", djs.balanceOf(address(djs)));
        
        address user1 = address(10);
        vm.startPrank(user);
        djs.transfer(user1, 1e18);
        vm.stopPrank();

        console.log("node usdt:", IERC20(USDT).balanceOf(address(nodeDividends)));
        uint256 amountUSDT = nodeDividends.perNftAward();
        console.log("perNFTAward:", amountUSDT);
    }

    
}