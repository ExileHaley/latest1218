// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Recharge} from "../src/Recharge.sol";
import {Sdt} from "../src/Sdt.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script{
    Recharge public recharge;
    Sdt     public sdt;
    address public admin;
    address public recipient;
    address public sender;

    address public tokenOwner;
    address public tokenRecipient;


    function setUp() public {

        recipient = vm.envAddress("RECIPIENT");
        admin = vm.envAddress("ADMIN");
        sender = vm.envAddress("SENDER");
        tokenRecipient = vm.envAddress("TOKEN_RECIPIENT");
        tokenOwner = vm.envAddress("TOKEN_OWNER");
        require(tokenRecipient != address(0), "Zero address.");
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(90_000_0000); // 0.09 gwei

        sdt = new Sdt(tokenRecipient);
        Recharge rechargeImpl = new Recharge();
        ERC1967Proxy rechargeProxy = new ERC1967Proxy(
            address(rechargeImpl),
            abi.encodeCall(rechargeImpl.initialize,(admin, recipient, sender))
        );
        recharge = Recharge(payable(address(rechargeProxy)));
        sdt.transferOwnership(tokenOwner);
        vm.stopBroadcast();
        console.log("sdt deployed at:", address(sdt));
        console.log("recharge deployed at:",address(recharge));
    }
}