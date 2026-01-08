// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRechargeScript is Script{
    Recharge public recharge;
    address  public router;
    address  public admin;
    address  public recipient;
    address  public sender;

    function setUp() public {
        router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        admin = address(0x7634C024C410e052054938A9a65a110B5A44B533);

    }

    function run() public {
        vm.startBroadcast();
        //deploy nodeDividends
        Recharge rechargeImpl = new Recharge();
        ERC1967Proxy rechargeProxy = new ERC1967Proxy(
            address(rechargeImpl),
            abi.encodeCall(rechargeImpl.initialize,(router, admin, recipient, sender))
        );
        recharge = Recharge(payable(address(rechargeProxy)));
        vm.stopBroadcast();
    }
    // address _router,address _admin, address _recipient, address _sender
    
}