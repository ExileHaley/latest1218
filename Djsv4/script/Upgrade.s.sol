// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Finance} from "../src/Finance.sol";
import {Router} from "../src/Router.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeScript is Script{

    Finance public finance;
    Router  public router;
    address public liquidityManager;

    function setUp() public {
        finance = Finance(payable(0x4c5ce1c4994225eD159efB36C9bd720c0F2caa99));
        liquidityManager = 0xC93C6201d0d16DD246198098AF92236890b7565F;
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(100_000_0000); // 0.09 gwei

        Finance financeV2Impl = new Finance();
        bytes memory data= "";
        finance.upgradeToAndCall(address(financeV2Impl), data);

        router = new Router(address(finance), liquidityManager);
        finance.setRouterAddr(address(router));

        vm.stopBroadcast();

        console.log("#### router:", address(router));
    }
    
}