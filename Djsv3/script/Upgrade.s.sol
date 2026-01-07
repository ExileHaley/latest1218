// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Finance} from "../src/Finance.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract UpgradeScript is Script {
    Finance public finance;

    function setUp() public {
        finance = Finance(payable(0x11611194d01065ED16193c1453e8B70F7D2C191E));
    }

    function run() public {
        vm.startBroadcast();
        Finance financeV2Impl = new Finance();
        bytes memory data= "";
        finance.upgradeToAndCall(address(financeV2Impl), data);
        
        vm.stopBroadcast();

    }
}