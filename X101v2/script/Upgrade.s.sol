// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {SpecifySell} from "../src/SpecifySell.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeScript is Script {
    SpecifySell public specifySell;

    function setUp() public {
        specifySell = SpecifySell(payable(0x68f60E8E519C29aBf4A96fcE4FF9B6e3474bA295));
    }

    function run() public {
        vm.startBroadcast();

        SpecifySell specifySellV2Impl = new SpecifySell();
        bytes memory data= "";
        specifySell.upgradeToAndCall(address(specifySellV2Impl), data);
        vm.stopBroadcast();
    
    }
}