// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Exchange} from "../src/Exchange.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeExchangeScript is Script{

    Exchange public exchange;


    function setUp() public {
        exchange = Exchange(payable(0x87924102384beEA7c10553283bE3b32BA8a7deB7));
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(100_000_0000); // 0.09 gwei

        Exchange impl = new Exchange();
        bytes memory data= "";
        exchange.upgradeToAndCall(address(impl), data);

        vm.stopBroadcast();
    }
    
}