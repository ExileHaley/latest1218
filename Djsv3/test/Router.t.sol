// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Finance} from "../src/Finance.sol";
import {Router} from "../src/Router.sol";
import {FinanceView} from "../src/FinanceView.sol";

contract RouterTest is Test{
    Finance public finance;
    Router  public router;
    FinanceView public financeView;

    address public owner;
    address public USDT;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);

        finance = Finance(payable(0x4c5ce1c4994225eD159efB36C9bd720c0F2caa99));
        financeView = FinanceView(0xCf633eBa368E41e28B11F5259dE74Ce37E972968);

        USDT = 0x55d398326f99059fF775485246999027B3197955;
        owner = 0xCf8f660e4de36a5c84A95104deC347b5891dD963;

        vm.startPrank(owner);
        upgradeFinance();
        router = new Router(address(finance));
        finance.setRouterAddr(address(router));
        vm.stopPrank();
    }

    function upgradeFinance() internal {
        Finance financeV2Impl = new Finance();
        bytes memory data= "";
        finance.upgradeToAndCall(address(financeV2Impl), data);
    }

    function _referral_utils(address user) internal{
        vm.startPrank(user);
        address rootAddr = router.initialCode();
        router.referral(rootAddr);
        vm.stopPrank();
    } 

    function _stake_utils(address user, uint256 amount) internal{
        vm.startPrank(user);
        deal(USDT, user, amount);
        IERC20(USDT).approve(address(finance), amount);
        router.stake(amount);
        vm.stopPrank();
    }

    function _claim_utils(address user) internal{
        vm.startPrank(user);
        router.claim();
        vm.stopPrank();
    }

    function test_stake() public {
        address user = address(1);
        uint256 amount = 200e18;
        _referral_utils(user);
        _stake_utils(user, amount);
        vm.warp(block.timestamp + 10 days);
        (
            uint256 stakingUsdt,
            ,
            ,
            ,
            uint256 extractable,
            ,   
        ) = financeView.getUserInfoBasic(user);
        assertEq(stakingUsdt, amount);
        console.log("extractable:", extractable);

        _claim_utils(user);
        (
            ,
            ,
            ,
            ,
            uint256 extractable0,
            ,   
        ) = financeView.getUserInfoBasic(user);
        assertEq(extractable0, 0);
    }

}
