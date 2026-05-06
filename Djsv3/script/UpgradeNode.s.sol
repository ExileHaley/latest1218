// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {NodeDividends} from "../src/NodeDividends.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeNodeScript is Script{

    NodeDividends public nodeDividends;
     

    function setUp() public {
        nodeDividends = NodeDividends(payable(0x24629495Bfd635a50B105efd602b104139eF2F8B));
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(100_000_0000); // 0.09 gwei

        NodeDividends impl = new NodeDividends();
        bytes memory data= "";
        nodeDividends.upgradeToAndCall(address(impl), data);

        vm.stopBroadcast();

    }
    
}