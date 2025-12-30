// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {X101v2} from "../src/X101v2.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SpecifySell} from "../src/SpecifySell.sol";
import {Gas} from "../src/Gas.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract X101Test is Test {
    // Counter public counter;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    X101v2 public x101;
    SpecifySell public specifySell;
    Gas public gas;
    address public user;

    address public router;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);
        router = address(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
        
        specifySell = SpecifySell(payable(0x68f60E8E519C29aBf4A96fcE4FF9B6e3474bA295));
        x101 = X101v2(0xE9FB723E203Aa48ebD5b5C215891aD9b83Ffa64F);
        gas = Gas(0x5c16d6dC352FfCD8b723b15001f99858857cbB43);
        user = address(1);
    }
    

    // function test_sell_error() public {
    //     vm.startPrank(initialRecipient);
    //     x101.transfer(user, 100e18);
    //     vm.stopPrank();

    //     vm.startPrank(user);
    //     x101.approve(router, 100e18);
    //     vm.expectRevert(bytes("TransferHelper: TRANSFER_FROM_FAILED"));
    //     address[] memory path = new address[](2);
    //     path[0] = address(x101);
    //     path[1] = adx;
       
    //     IUniswapV2Router02(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //         100e18, 
    //         0, 
    //         path, 
    //         user, 
    //         block.timestamp + 10
    //     );
    //     vm.stopPrank();

    // }

    function test_sell_success() public {
        
        vm.startPrank(user);
        deal(address(x101), user, 100e18);

        uint256 beforeGasAmount = gas.balanceOf(DEAD);
        console.log("Before balance gas for dead:", beforeGasAmount);
        uint256 beforeX101Amount = x101.balanceOf(DEAD);
        console.log("Before balance x101 for dead:", beforeX101Amount);

        uint256 gasBurn = specifySell.getAmountOut(100e18);
        console.log("Burn gas amount compute:",gasBurn);
        deal(address(gas), user, gasBurn);
        x101.approve(address(specifySell), 100e18);
        specifySell.sellForX101(100e18);

        uint256 afterGasAmount = gas.balanceOf(DEAD);
        console.log("After balance gas for dead:", afterGasAmount);
        uint256 afetrX101Amount = x101.balanceOf(DEAD);
        console.log("After balance x101 for dead:", afetrX101Amount);
        // assertEq(gasBurn, afterGasAmount - beforeGasAmount);
        assertEq(20e18, afetrX101Amount - beforeX101Amount);
        vm.stopPrank();
    }
}
