// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Gas} from "../src/Gas.sol";
import {X101v2} from "../src/X101v2.sol";

contract UpgradeScript is Script {
    Recharge public recharge;
    Gas      public gas;
    X101v2     public x101;
    address public initialRecipient;

    function setUp() public {
        recharge = Recharge(payable(0x5be240960c507F1f9425419512fd765732B0cf65));
        initialRecipient = address(0x3aC23Ac4FD55B16b2EdFB847d30614226Cba645f);
    }

    function run() public {
        vm.startBroadcast();

        gas = new Gas();
        x101 = new X101v2(initialRecipient);

        Recharge rechargeV2Impl = new Recharge();
        bytes memory data= "";
        recharge.upgradeToAndCall(address(rechargeV2Impl), data);
        recharge.setTokenAddr(address(gas), address(x101));
        x101.setRecharge(address(recharge));
        gas.mint(address(recharge), 3030000e18);

        
        vm.stopBroadcast();
        console.log("Allowlist:", x101.allowlist(address(recharge)));
        console.log("Recharge address:", x101.recharge());
        console.log("Gas deployed at:", address(gas));
        console.log("X101 deployed at:", address(x101));

    }
}