// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {Djsc} from "../src/Djsc.sol";

contract DjscTest is Test{
    Djsc public djsc;
    address public technology;
    address public foundation;
    address public marketing;
    address public pot;

    address public sellFee;
    address public buyFee;
    address public profitFee;

    address public USDT;
    address public uniswapV2Router;

    address public user;
    address public owner;
    uint256 mainnetFork;    
    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);
        //mainnet address
        uniswapV2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        USDT = address(0x55d398326f99059fF775485246999027B3197955);
        
        technology = address(1);
        foundation = address(2);
        marketing = address(3);
        pot = address(4);

        sellFee = address(5);
        buyFee = address(6);
        profitFee = address(7);
        
        user = address(8);
        owner = address(9);

        address[4] memory addrs = [technology, foundation, marketing, pot];
        vm.startPrank(owner);
        djsc = new Djsc(addrs, sellFee, buyFee, profitFee);
        vm.stopPrank();

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

    function _swap(address addr, address fromToken, address toToken, uint256 fromAmount) internal{
        vm.startPrank(addr);
        IERC20(fromToken).approve(uniswapV2Router, fromAmount);
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            fromAmount, 
            0, 
            path, 
            addr, 
            block.timestamp + 10
        );
        vm.stopPrank();
    }


    function test_transfer_totalCost() public {
        // test_buy_not_allowlist_cost();
        deal(USDT, user, 100e18);
        _swap(user, USDT, address(djsc), 100e18);

        uint256 oneHalf = djsc.balanceOf(user) / 2;
        uint256 totalCost = djsc.totalCostUsdt(user);
        uint256 oneHalfCost = totalCost / 2;
        address user1 = address(10);
        vm.startPrank(user);
        djsc.transfer(user1, oneHalf);
        assertEq(djsc.balanceOf(user1), oneHalf);
        assertEq(djsc.totalCostUsdt(user1), oneHalfCost);
        assertEq(djsc.totalCostUsdt(user), totalCost - oneHalfCost);
        vm.stopPrank();
    }

    function test_sell_not_allowlist_profit() public {
        console.log("Usdt before swap balance of:", IERC20(USDT).balanceOf(profitFee));
        console.log("profitFee address:",profitFee);
        deal(USDT, user, 100e18);
        _swap(user, USDT, address(djsc), 100e18);

        address user1 = address(10);
        deal(USDT, user1, 1000e18);
        _swap(user1, USDT, address(djsc), 1000e18);

        uint256 balanceToken = djsc.balanceOf(user);
        _swap(user, address(djsc), USDT, balanceToken);

        console.log("Usdt after swap balance of:", IERC20(USDT).balanceOf(profitFee));
    }

    function test_transfer_cost_after_profit() public {
        deal(USDT, user, 1000e18);
        _swap(user, USDT, address(djsc), 100e18);

        uint256 oneHalf = djsc.balanceOf(user) / 2;
        address user1 = address(10);
        console.log("before sell usdt balance of User1:", IERC20(USDT).balanceOf(user1));
        vm.startPrank(user);
        djsc.transfer(user1, oneHalf);
        vm.stopPrank();

        _swap(user, USDT, address(djsc), 900e18);
        _swap(user1, address(djsc), USDT, oneHalf);
        console.log("after sell usdt balance of User1:", IERC20(USDT).balanceOf(user1));
        console.log("Usdt after user1 swap balance of:", IERC20(USDT).balanceOf(profitFee));
    }

    function test_transfer() public {
        deal(USDT, user, 1000e18);
        _swap(user, USDT, address(djsc), 100e18);

        uint256 total = djsc.balanceOf(user);
        uint256 oneHalf = total / 2;
        
        address user1 = address(10);
        vm.startPrank(user);
        djsc.transfer(user1, oneHalf);
        vm.stopPrank();

        assertEq(djsc.balanceOf(user1), oneHalf);
        assertEq(djsc.balanceOf(user), total - oneHalf);
    }

    function test_buyFee() public {
        console.log("Before swap buy fee:",IERC20(USDT).balanceOf(buyFee));
        console.log("Before buy djsc balance of token:", djsc.balanceOf(address(djsc)));
        deal(USDT, user, 1000e18);
        _swap(user, USDT, address(djsc), 100e18);
        // assertEq(left, right);
        console.log("After buy djsc balance of token:", djsc.balanceOf(address(djsc)));

        uint256 total = djsc.balanceOf(user);
        uint256 oneHalf = total / 2;
        address user1 = address(10);
        vm.startPrank(user);
        djsc.transfer(user1, oneHalf);
        vm.stopPrank();
        assertEq(djsc.balanceOf(address(djsc)), 0);
        console.log("After swap buy fee:",IERC20(USDT).balanceOf(buyFee));
    }


    function test_sellFee() public {
        console.log("Before swap sell fee:",IERC20(USDT).balanceOf(sellFee));
        vm.startPrank(pot);
        djsc.transfer(user, 100e18);
        vm.stopPrank();

        _swap(user, address(djsc), USDT, 100e18);
        assertEq(IERC20(USDT).balanceOf(profitFee), 402005021947888389);
        console.log("After swap sell fee:",IERC20(USDT).balanceOf(sellFee));
    }

    function test_not_allowlist_addLiquidity() public {
        vm.startPrank(pot);
        djsc.transfer(user, 10000e18);
        vm.stopPrank();

        console.log("Before add liquidity usdt balance sell fee:",IERC20(USDT).balanceOf(sellFee));
        vm.startPrank(user);
        deal(USDT, user, 10000e18);

        djsc.approve(uniswapV2Router, 10000e18);
        IERC20(USDT).approve(uniswapV2Router, 10000e18);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            address(djsc), 
            USDT, 
            10000e18, 
            10000e18, 
            0, 
            0, 
            user, 
            block.timestamp + 10
        );
       

        vm.stopPrank();
        assertEq(djsc.balanceOf(djsc.pancakePair()), 20000e18);
        console.log("After add liquidity usdt balance sell fee:",IERC20(USDT).balanceOf(sellFee));
        //15  101005021947888389
        //305 656142531960753403
    }

    function test_not_allowlist_removeLiquidity() public {
        test_not_allowlist_addLiquidity();
        uint256 lpBalance = IERC20(djsc.pancakePair()).balanceOf(user);
        console.log("before remove liquidity djsc balance of user:", djsc.balanceOf(user));

        vm.startPrank(user);
        IERC20(djsc.pancakePair()).approve(uniswapV2Router, lpBalance);
        IUniswapV2Router02(uniswapV2Router).removeLiquidity(
            address(djsc), 
            USDT, 
            lpBalance, 
            0, 
            0, 
            user, 
            block.timestamp + 10
        );
        console.log("after remove liquidity djsc balance of user:", djsc.balanceOf(user));
        vm.stopPrank();
    }

}