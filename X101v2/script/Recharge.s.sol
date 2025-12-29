// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RechargeScript is Script{
    Recharge public recharge;

    // address _router,address _admin, address _recipient, address _sender
    address public router;
    address public admin; 
    address public recipient;
    address public sender;

    function setUp() public {
        //nadi
        // router = address(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
        //bsc
        router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        admin = address(0x664bCfA4bC5C7DC24764E2F109ec81AD6EF4A2bf);
        // admin = address(0xD306aC9A106D062796848C208021c3f44624e66a);
        recipient = address(0x6a1db8B4F097EC02E86678B7d5825eCA284002Bb);
        sender = address(0x834e6B9211fe42273873AC209ef4c2C116CD2b26);
    }

    function run() public {
        vm.startBroadcast();
        
        //deploy recharge
        Recharge rechargeImpl = new Recharge();
        ERC1967Proxy rechargeProxy = new ERC1967Proxy(
            address(rechargeImpl),
            abi.encodeCall(rechargeImpl.initialize,(router, admin, recipient, sender))
        );
        recharge = Recharge(payable(address(rechargeProxy)));
        vm.stopBroadcast();
        console.log("Recharge deployed at:",address(recharge));
    }    

}