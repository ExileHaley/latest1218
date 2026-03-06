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
        console.log("test_buy cost:", cost);

        uint256 toNode = djs.balanceOf(address(djs));
        console.log("test_buy to node:",toNode);
    }

    function test_sell_no_profit() public{
        vm.startPrank(initialRecipient);
        djs.transfer(user, 100e18);
        vm.stopPrank();
        test_exchange_utils(user, address(djs), USDT, 100e18);
        assertEq(djs.balanceOf(address(djs)), 0);
    }
    
    function test_sell_normal_profit_fixed() public {
        // user buy
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);

        // manipulate pool to increase price
        deal(USDT, address(10), 10000e18);
        test_exchange_utils(address(10), USDT, address(djs), 10000e18);

        // now user sell all
        uint256 amountToSell = djs.balanceOf(user);
        console.log("test_sell_normal_profit_fixed balance of user:", amountToSell);

        uint256 amountTax = djs.getProfitTaxToken(user, amountToSell);
        console.log("test_sell_normal_profit amount tax:", amountTax);
        assert(amountTax > 0);
        
        uint256 beforeSellUsdtOf = IERC20(USDT).balanceOf(walletForProfit);
        test_exchange_utils(user, address(djs), USDT, amountToSell);
        uint256 afterSellUsdtOf = IERC20(USDT).balanceOf(walletForProfit);
        console.log("test_sell_normal_profit_fixed profit fee:", afterSellUsdtOf - beforeSellUsdtOf);

        assertEq(djs.totalCostUsdt(user), 0);
    }

    function test_sell_oneHalf_profitFee() public {
        // user buy
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);

        // manipulate pool to increase price
        deal(USDT, address(10), 10000e18);
        test_exchange_utils(address(10), USDT, address(djs), 10000e18);

        // now user sell all
        uint256 amountToSell = djs.balanceOf(user);
        uint256 amountTax = djs.getProfitTaxToken(user, amountToSell / 2);
        assert(amountTax > 0);

        uint256 beforeSellUsdtOf = IERC20(USDT).balanceOf(walletForProfit);
        test_exchange_utils(user, address(djs), USDT, amountToSell / 2);
        uint256 afterSellUsdtOf = IERC20(USDT).balanceOf(walletForProfit);

        console.log("test_sell_oneHalf_profitFee profit fee:", afterSellUsdtOf - beforeSellUsdtOf);
        console.log("test_sell_oneHalf_profitFee after total cost:",djs.totalCostUsdt(user));
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

        uint256 nodeProfitFee = IERC20(USDT).balanceOf(address(nodeDividends));
        assert(nodeProfitFee > 0);
    }

    function test_transfer_updateCost() public {
        deal(USDT, user, 100e18);
        test_exchange_utils(user, USDT, address(djs), 100e18);
        uint256 amountOfUser = djs.balanceOf(user);

        address user1 = address(10);
        vm.startPrank(user);
        djs.transfer(user1, amountOfUser / 2);
        vm.stopPrank();

        uint256 userCost = djs.totalCostUsdt(user);
        assert(userCost > 45e18);

        uint256 user1Cost = djs.totalCostUsdt(user1);
        assert(user1Cost > 45e18);

    }
}