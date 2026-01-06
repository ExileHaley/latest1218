// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Finance} from "../src/Finance.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    Finance public finacne;
    address public initialCode;
    address public recipient;

    function setUp() public {
        // initialCode = 
        // recipient = 
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
    }
}
