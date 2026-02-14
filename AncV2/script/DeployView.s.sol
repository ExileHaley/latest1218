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
    FarmCore  farmCore;
    FarmReferral farmReferral;
    FarmNode farmNode;
    FarmToday farmToday;
    FarmView farmView;

    function setUp() public {
        farmCore = FarmCore(payable(0x61C5A58ebbE019fcF7F0E0681079f8c40f0edBb1));
        farmReferral = FarmReferral(payable(0x25eD0a93865654b0f9D7880B12cf5e923235031A));
        farmNode = FarmNode(payable(0xF8fE1097F9216570A25025222A446602C372eeB8));
        farmToday = FarmToday(payable(0xb4a82546FdDb1C2DeEBbCF0C146706383Cc1Ae43));
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(90_000_0000); // 0.09 gwei
        FarmCore farmCoreV2Impl = new FarmCore();
        bytes memory data= "";
        farmCore.upgradeToAndCall(address(farmCoreV2Impl), data);
        // FarmCore _farmCore,
        // FarmNode _farmNode,
        // FarmReferral _farmReferral,
        // FarmToday _farmToday
        farmView = new FarmView(farmCore, farmNode, farmReferral, farmToday);
        vm.stopBroadcast();
        console.log("FarmView deployed at:", address(farmView));
    }
}