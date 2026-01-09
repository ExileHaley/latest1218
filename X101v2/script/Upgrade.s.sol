// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {X101v2} from "../src/X101v2.sol";
import {MultiTransfer} from "../src/MultiTransfer.sol";

contract UpgradeScript is Script {
    MultiTransfer public multiTransfer;
    Recharge public recharge;
    X101v2   public x101v2;
    address  public recipient;
    address  public gas;
    address  public x101v1;
    address  public admin;

    function setUp() public {
        recharge = Recharge(payable(0x5be240960c507F1f9425419512fd765732B0cf65));
        gas = address(0x3c83065B83A8Fd66587f330845F4603F7C49275c);
        x101v1 = address(0xa8d372f9151Dc72b7B351EE046BCACEc814dc0b0);
        recipient = address(0x3862120B1570c5D0285d15c9E0A6a38DdCf6569A);
        admin = address(0x27500f497A6195913ad93eaA7f9ffce9C156350a);
    }


    function run() public {
        vm.startBroadcast();
        //部署x101v2
        x101v2 = new X101v2(recipient);
        //x101v2设置recharge
        x101v2.setRecharge(address(recharge));
        //recharge 设置x101v2地址
        recharge.setTokenAddr(gas, address(x101v2));
        //部署空投合约
        multiTransfer = new MultiTransfer(x101v1);
        //给空投合约设置白名单
        address[] memory addrs = new address[](1);
        addrs[0] = address(multiTransfer);
        x101v2.setAllowlist(addrs, true);
        
        //x101v2代币转移管理员
        x101v2.transferOwnership(recipient);
        //multiTransfer转移管理员
        multiTransfer.transferOwnership(admin);
        vm.stopBroadcast();

        console.log("X101v2 deployed at:", address(x101v2));
        console.log("MultiTransfer deployed at:", address(multiTransfer));
    }
}