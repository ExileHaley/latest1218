// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Finance} from "../src/Finance.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    Finance public finacne;
    address public initialCode;
    address public recipient;

    function setUp() public {
        initialCode = address(0x92A5A7A4F6B2e0b9107b66B459d5f0eB219dc7B2);
        recipient = address(0x92A5A7A4F6B2e0b9107b66B459d5f0eB219dc7B2);
    }

    function run() public {
        vm.startBroadcast();

        Finance financeImpl = new Finance();
        ERC1967Proxy finacneProxy = new ERC1967Proxy(
            address(financeImpl),
            abi.encodeCall(financeImpl.initialize,(initialCode, recipient))
        );
        finacne = Finance(payable(address(finacneProxy)));

        vm.stopBroadcast();
        console.log("Finance deployed at:", address(finacne));
    }
}
