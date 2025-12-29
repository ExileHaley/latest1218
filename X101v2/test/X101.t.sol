// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {X101v2} from "../src/X101v2.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SpecifySell} from "../src/SpecifySell.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract X101Test is Test {
    // Counter public counter;
    X101v2 public x101;
    SpecifySell public specifySell;
    address public initialRecipient;
    address public adx;
    address public dead;
    address public gas;

    address public owner;
    address public user;

    address public router;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);
        router = address(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
        adx = address(0x68a4d37635cdB55AF61B8e58446949fB21f384e5);
        dead = address(0x000000000000000000000000000000000000dEaD);
        initialRecipient = address(1);
        owner = address(2);
        user = address(3);

        vm.startPrank(owner);
        x101 = new X101v2(initialRecipient);
        //deploy SpecifySell
        SpecifySell specifySellImpl = new SpecifySell();
        ERC1967Proxy specifySellProxy = new ERC1967Proxy(
            address(specifySellImpl),
            abi.encodeCall(specifySellImpl.initialize,(router, address(x101), gas))
        );
        specifySell = SpecifySell(payable(address(specifySellProxy)));
        x101.setSpecifySell(address(specifySell));
        vm.stopPrank();

        addLiquidity_allowlist();
    }
    
    function addLiquidity_allowlist() internal{
        vm.startPrank(initialRecipient);
        deal(adx, initialRecipient, 10000e18);

        x101.approve(router, 10000e18);
        IERC20(adx).approve(router, 10000e18);

        IUniswapV2Router02(router).addLiquidity(
            address(x101), 
            adx, 
            10000e18, 
            10000e18, 
            0, 
            0, 
            initialRecipient, 
            block.timestamp + 10
        );

        vm.stopPrank();
        assertEq(x101.balanceOf(x101.pancakePair()), 10000e18);
    }

    function test_sell_error() public {
        vm.startPrank(initialRecipient);
        x101.transfer(user, 100e18);
        vm.stopPrank();

        vm.startPrank(user);
        x101.approve(router, 100e18);
        vm.expectRevert(bytes("TransferHelper: TRANSFER_FROM_FAILED"));
        address[] memory path = new address[](2);
        path[0] = address(x101);
        path[1] = adx;
       
        IUniswapV2Router02(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100e18, 
            0, 
            path, 
            user, 
            block.timestamp + 10
        );
        vm.stopPrank();

    }

    function test_sell_success() public {
        vm.startPrank(initialRecipient);
        x101.transfer(user, 100e18);
        vm.stopPrank();

        vm.startPrank(user);
        x101.approve(address(specifySell), 100e18);
        specifySell.sellForX101(100e18);
        assertEq(x101.balanceOf(x101.pancakePair()), 10080e18);
        vm.stopPrank();
    }
}
