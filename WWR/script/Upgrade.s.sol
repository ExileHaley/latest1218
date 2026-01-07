// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Finance} from "../src/Finance.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract UpgradeScript is Script {
    Finance public finance;

    function setUp() public {
        finance = Finance(payable(0x557B04D6D2D1Fa9f1abD5785b83C44E24667b992));
    }

    function run() public {
        vm.startBroadcast();
        Finance financeV2Impl = new Finance();
        bytes memory data= "";
        finance.upgradeToAndCall(address(financeV2Impl), data);
        finance.setPrice(1e17, 2e17, 3e17);
        vm.stopBroadcast();

    }
}