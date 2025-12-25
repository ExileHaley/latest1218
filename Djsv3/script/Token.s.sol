// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Tether} from "../src/mock/Tether.sol";

contract TetherScript is Script{
    Tether public usdt;
    address public initialRecipient;

    function setUp() public {
        initialRecipient = 0xf93BbB196a961F7e8B54900DBb38e84a6d1fC937;
    }

    function run() public {
        
        vm.startBroadcast();
        usdt = new Tether(initialRecipient);
        vm.stopBroadcast();

        console.log("Usdt deployed at:",address(usdt));
    }
}

//forge script script/Token.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]