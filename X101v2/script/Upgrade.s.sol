// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Gas} from "../src/Gas.sol";
import {X101v2} from "../src/X101v2.sol";

contract UpgradeScript is Script {
    Recharge public recharge;

    function setUp() public {
        recharge = Recharge(payable(0x5be240960c507F1f9425419512fd765732B0cf65));
    }

    function run() public {
        vm.startBroadcast();
        Recharge rechargeV2Impl = new Recharge();
        bytes memory data= "";
        recharge.upgradeToAndCall(address(rechargeV2Impl), data);
        
        vm.stopBroadcast();

    }
}