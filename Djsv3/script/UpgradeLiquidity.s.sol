// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeLiquidityScript is Script{

    LiquidityManager public liquidityManager;
     

    function setUp() public {
        liquidityManager = LiquidityManager(payable(0xC93C6201d0d16DD246198098AF92236890b7565F));
    }

    function run() public {
        vm.startBroadcast();
        vm.txGasPrice(100_000_0000); // 0.09 gwei

        LiquidityManager liquidityManagerImpl;
        liquidityManagerImpl = new LiquidityManager();
        bytes memory data= "";
        liquidityManager.upgradeToAndCall(address(liquidityManagerImpl), data);
        bytes32 implSlot = 0x360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC;

        bytes32 raw = vm.load(address(liquidityManager), implSlot);
        address impl = address(uint160(uint256(raw)));

        assert(address(liquidityManagerImpl) == impl);

        vm.stopBroadcast();

        console.log("#### liquidityManagerImpl:", address(liquidityManagerImpl));
    }
    
}