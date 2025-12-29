// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NodeDividends}  from "../src/NodeDividends.sol";

interface IFinance{
    function setNodeDividends(address _nodeDividends) external;
}
contract DeployNodeScript is Script{
    NodeDividends public nodeDividends;
    address public finance;
    address public nfts;
    address public djs;

    function setUp() public {
        finance = 0xeA7eB2F853b23450798a3A98c94C8fd6Cd029dD1;
        nfts = 0x20D872c41B1373FC9772cbda51609359caFB3748;
        djs = 0x75B8c892FC65fFF466a7b84A5c5b8aC8ec1395A5;
    }

    function run() public{
        vm.startBroadcast();

        NodeDividends nodeImpl = new NodeDividends();
        ERC1967Proxy nodeProxy = new ERC1967Proxy(
            address(nodeImpl),
            abi.encodeCall(nodeImpl.initialize,(nfts, djs))
        );
        nodeDividends = NodeDividends(payable(address(nodeProxy)));

        IFinance(finance).setNodeDividends(address(nodeDividends));
        nodeDividends.setStaking(finance);
        vm.stopBroadcast();

        console.log("NodeDividends deployed at:",address(nodeDividends));
    }
}