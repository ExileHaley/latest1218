// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Finance}  from "../src/Finance.sol";

contract UpgradeFinanceScript is Script{
    Finance public finance;

    function setUp() public {
        finance = Finance(payable(0xeA7eB2F853b23450798a3A98c94C8fd6Cd029dD1));
    }

    function run() public {
        vm.startBroadcast();

        Finance financeV2Impl = new Finance();
        bytes memory data= "";
        finance.upgradeToAndCall(address(financeV2Impl), data);
        vm.stopBroadcast();
        
    }
}