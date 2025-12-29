// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Gas} from "../src/Gas.sol";
import {X101v2} from "../src/X101v2.sol";
// import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TokenScript is Script {
    Gas     public gas;
    X101v2  public x101;
    address public initialRecipient;


    function setUp() public {
        initialRecipient = address(0x3aC23Ac4FD55B16b2EdFB847d30614226Cba645f);
    }

    function run() public {
        vm.startBroadcast();
        gas = new Gas(initialRecipient);
        x101 = new X101v2(initialRecipient, address(gas));
        gas.setX101Addr(address(x101));

        //transfer owner permit
        gas.transferOwnership(initialRecipient);
        x101.transferOwnership(initialRecipient);

        vm.stopBroadcast();

        console.log("Gas deployed at:",address(gas));
        console.log("X101 deployed at:",address(x101));
    }

    
}
