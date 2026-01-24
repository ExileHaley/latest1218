// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeScript is Script{
    LiquidityManager public liquidityManager;
    address admin;

    function setUp() public {
        liquidityManager = LiquidityManager(payable(0x4c5ce1c4994225eD159efB36C9bd720c0F2caa99));
        admin = 0x45588b73995fce652F75D5BadCeFF3c93e4f62b3;
    }

    function run() public {
        vm.startBroadcast();

        LiquidityManager liquidityManagerV2Impl = new LiquidityManager();
        bytes memory data= "";
        liquidityManager.upgradeToAndCall(address(liquidityManagerV2Impl), data);
        liquidityManager.setAdmin(admin);
        vm.stopBroadcast();
        
    }
}