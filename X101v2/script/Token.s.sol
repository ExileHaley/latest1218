// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Gas} from "../src/Gas.sol";
import {X101v2} from "../src/X101v2.sol";
import {SpecifySell} from "../src/SpecifySell.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TokenScript is Script {
    Gas     public gas;
    X101v2  public x101;
    address public initialRecipient;
    SpecifySell public specifySell;
    address public router;


    function setUp() public {
        initialRecipient = address(0x3aC23Ac4FD55B16b2EdFB847d30614226Cba645f);
        router = address(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
    }

    function run() public {
        vm.startBroadcast();
        gas = new Gas(initialRecipient);
        x101 = new X101v2(initialRecipient);
        //deploy specifySell
        SpecifySell specifySellImpl = new SpecifySell();
        ERC1967Proxy specifySellProxy = new ERC1967Proxy(
            address(specifySellImpl),
            abi.encodeCall(specifySellImpl.initialize,(router, address(x101), address(gas)))
        );
        specifySell = SpecifySell(payable(address(specifySellProxy)));

        //set specifySell
        x101.setSpecifySell(address(specifySell));
        gas.setSpecifySell(address(specifySell));

        //transfer owner permit
        gas.transferOwnership(initialRecipient);
        x101.transferOwnership(initialRecipient);

        vm.stopBroadcast();

        console.log("Gas deployed at:",address(gas));
        console.log("X101 deployed at:",address(x101));
        console.log("SpecifySell deployed at:",address(specifySell));
    }

}
