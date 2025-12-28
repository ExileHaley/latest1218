// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Gas} from "../src/Gas.sol";
import {X101v2} from "../src/X101v2.sol";
import {Recharge} from "../src/Recharge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    Gas     public gas;
    X101v2  public x101;
    Recharge public recharge;

    address public initialRecipient;
    address public router;
    address public admin; 
    address public recipient;
    address public sender;

    // Counter public counter;

    function setUp() public {
        router = address(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
        initialRecipient = address(0x3aC23Ac4FD55B16b2EdFB847d30614226Cba645f);
        // admin = address(0x664bCfA4bC5C7DC24764E2F109ec81AD6EF4A2bf);
        admin = address(0xD306aC9A106D062796848C208021c3f44624e66a);
        recipient = address(0x6a1db8B4F097EC02E86678B7d5825eCA284002Bb);
        sender = address(0x834e6B9211fe42273873AC209ef4c2C116CD2b26);
    }

    function run() public {
        vm.startBroadcast();
        gas = new Gas(initialRecipient);
        x101 = new X101v2(initialRecipient, address(gas));
        gas.setX101Addr(address(x101));

        //deploy recharge
        Recharge rechargeImpl = new Recharge();
        ERC1967Proxy rechargeProxy = new ERC1967Proxy(
            address(rechargeImpl),
            abi.encodeCall(rechargeImpl.initialize,(router, admin, recipient, sender))
        );
        recharge = Recharge(payable(address(rechargeProxy)));

        //add recharge allowlist
        address[] memory addrs = new address[](1);
        addrs[0] = address(recharge);
        x101.setAllowlist(addrs, true);

        //transfer owner permit
        gas.transferOwnership(initialRecipient);
        x101.transferOwnership(initialRecipient);

        vm.stopBroadcast();

        console.log("Gas deployed at:",address(gas));
        console.log("X101 deployed at:",address(x101));
        console.log("Recharge deployed at:",address(recharge));
    }
}
