// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Gather} from "../src/Gather.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {

    Gather public gather;
    address  public recipient;

    function setUp() public {
        recipient = 0x0B5b96f5dC169aaD6628feEb89090Ca18605B3B7;
    }


    function run() public {
        
        vm.startBroadcast();

        Gather gatherImpl = new Gather();
        ERC1967Proxy gatherProxy = new ERC1967Proxy(
            address(gatherImpl),
            abi.encodeCall(gatherImpl.initialize,(recipient))
        );
        gather = Gather(payable(address(gatherProxy)));
        
        vm.stopBroadcast();
        console.log("gather deployed at:",address(gather));
    }
}