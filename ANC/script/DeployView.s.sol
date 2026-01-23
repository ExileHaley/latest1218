// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FarmCore} from "../src/FarmCore.sol";
import {FarmNode} from "../src/FarmNode.sol";
import {FarmReferral} from "../src/FarmReferral.sol";
import {FarmToday} from "../src/FarmToday.sol";

import {FarmView} from "../src/FarmView.sol";


contract DeployViewScript is Script{

    FarmCore farmCore;
    FarmReferral farmReferral;
    FarmNode farmNode;
    FarmToday farmToday;
    FarmView farmView;

// #### farmCore:0x63480bcdBC30EEDa70308F10c39585F61CAf29c7
// #### farmReferral:0x9B2DfA8ff3c44D928085c9208B5B9430eC66dc3B
// #### farmNode:0x348E9C4D8049a29FA97f970427d293dcbb6c5ab3
// #### farmToday:0x42Fa8067d9948D6cB0EFDf6F8Ed5F822414998Fc


    function setUp() public {
        farmCore = FarmCore(payable(0x63480bcdBC30EEDa70308F10c39585F61CAf29c7));
        farmReferral = FarmReferral(payable(0x9B2DfA8ff3c44D928085c9208B5B9430eC66dc3B));
        farmNode = FarmNode(payable(0x348E9C4D8049a29FA97f970427d293dcbb6c5ab3));
        farmToday = FarmToday(payable(0x42Fa8067d9948D6cB0EFDf6F8Ed5F822414998Fc));
    }

    function run() public {
        vm.startBroadcast();
        farmView = new FarmView(farmCore, farmNode, farmReferral, farmToday);
        vm.stopBroadcast();
        console.log("FarmView deployed at:",address(farmView));
    }
}