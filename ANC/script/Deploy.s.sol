// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Anc} from "../src/Anc.sol";
import {TToken}  from "../src/mock/TToken.sol";


import {FarmCore} from "../src/FarmCore.sol";
import {FarmNode} from "../src/FarmNode.sol";
import {FarmReferral} from "../src/FarmReferral.sol";
import {FarmToday} from "../src/FarmToday.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";

contract DeployScript is Script {
    Anc anc;
    address initialRecipient;
    address recipient;
    address community;
    address buyBack;
    TToken  USDT;


    FarmCore farmCore;
    address admin;
    FarmReferral farmReferral;
    address initialCode;
    FarmNode farmNode;
    FarmToday farmToday;
    LiquidityManager liquidityManager;

    function setUp() public {
        // initialRecipient = address();
        // recipient = address();
        // community = address();
        // buyBack = address();
        // admin = address();
        // initialCode = address();
    }

    function run() public {
        vm.startBroadcast();
        // USDT init(_initialRecipient)
        USDT = new TToken(initialRecipient);
        //Anc init(
        //     address _initialRecipient, 
        //     address _recipient,
        //     address _community,
        //     address _buyBack,
        //     address _USDT
        // )
        anc = new Anc(initialRecipient, recipient, community, buyBack, address(USDT));

        //deploy proxy
        // liquidityManager init(
        //     address _USDT,
        //     address _tokenAnc
        // )
        // deploy liquidityManager
        LiquidityManager liquidityManagerImpl = new LiquidityManager();
        ERC1967Proxy liquidityManagerProxy = new ERC1967Proxy(
            address(liquidityManagerImpl),
            abi.encodeCall(liquidityManagerImpl.initialize,(address(USDT), address(anc)))
        );
        liquidityManager = LiquidityManager(payable(address(liquidityManagerProxy)));

        //deploy farmReferral
        // farmReferral init(address _initialCode)
        FarmReferral farmReferralImpl = new FarmReferral();
        ERC1967Proxy farmReferralProxy = new ERC1967Proxy(
            address(farmReferralImpl),
            abi.encodeCall(farmReferralImpl.initialize,(initialCode))
        );
        farmReferral = FarmReferral(payable(address(farmReferralProxy)));

        //deploy farmToday
        FarmToday farmTodayImpl = new FarmToday();
        ERC1967Proxy farmTodayProxy = new ERC1967Proxy(
            address(farmTodayImpl),
            abi.encodeCall(farmTodayImpl.initialize,())
        );
        farmToday = FarmToday(payable(address(farmTodayProxy)));

        //deploy farmNode
        FarmNode farmNodeImpl = new FarmNode();
        ERC1967Proxy farmNodeProxy = new ERC1967Proxy(
            address(farmNodeImpl),
            abi.encodeCall(farmNodeImpl.initialize,())
        );
        farmNode = FarmNode(payable(address(farmNodeProxy)));

        // farmCore init(
        //     address _admin,
        //     address _community,
        //     address _buyBack,
        //     address _USDT,
        //     address _ANC,
        //     FarmReferral _farmReferral,
        //     FarmNode _farmNode,
        //     FarmToday _farmToday,
        //     LiquidityManager _liquidityManager
        // )
        //deploy farmCore
        FarmCore farmCoreImpl = new FarmCore();
        ERC1967Proxy farmCoreProxy = new ERC1967Proxy(
            address(farmCoreImpl),
            abi.encodeCall(farmCoreImpl.initialize,(
                admin,
                community,
                buyBack,
                address(USDT),
                address(anc),
                farmReferral,
                farmNode,
                farmToday,
                liquidityManager
            ))
        );
        farmCore = FarmCore(payable(address(farmCoreProxy)));

        vm.stopBroadcast();

        console.log("Tether deployed at:", address(USDT));
        console.log("Anc deployed at:",address(anc));
        console.log("Anc`s pancake pair:", anc.pancakePair());

        console.log("LiquidityManager deployed at:",address(liquidityManager));
        console.log("FarmReferral deployed at:",address(farmReferral));
        console.log("FarmToday view deployed at:",address(farmToday));
        console.log("FarmNode deployed at:",address(farmNode));
        console.log("FarmCore deployed at:",address(farmCore));
    }
}