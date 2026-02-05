// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Exchange}  from "../src/Exchange.sol";

contract DeployExchangeScript is Script{
    Exchange public exchange;
    address  public admin;
    address  public recipient;

    function setUp() public {
        // uint256 deployerPk = vm.envUint("PRIVATE_KEY");后续可以使用这种方式

        admin = vm.envAddress("EXCHANGE_ADMIN");
        recipient = vm.envAddress("EXCHANGE_RECIPIENT");
        require(admin != address(0), "ADMIN_ZERO");
        require(recipient != address(0), "RECIPIENT_ZERO");
    }

    function run() public {
        vm.startBroadcast();
        //deploy nodeDividends
        Exchange exchangeImpl = new Exchange();
        ERC1967Proxy exchangeProxy = new ERC1967Proxy(
            address(exchangeImpl),
            abi.encodeCall(exchangeImpl.initialize,(admin, recipient))
        );
        exchange = Exchange(payable(address(exchangeProxy)));

        assert(exchange.admin() == admin);
        assert(exchange.recipient() == recipient);
        vm.stopBroadcast();
        // vm.startBroadcast(pk);后续可以使用这种方式
        console.log("Exchange deployed at:",address(exchange));
    }
}