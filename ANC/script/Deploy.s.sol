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
import {FarmView} from "../src/FarmView.sol";

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

    FarmView farmView;

    function setUp() public {
        initialRecipient = address(0xf28a8D50d73D1c17Fb212018aCE61E6ec7defBc5);
        recipient = address(0xFbAA63fe100a513E1f52585eD9bfc4F273652F14);
        community = address(0x63ff70308FB79a583C2684B7407305107E4a3A56);
        buyBack = address(0x2bc0AcA0C99596f8C84578bFa729858f6A7a7443);
        admin = address(0xCf8f660e4de36a5c84A95104deC347b5891dD963);
        initialCode = address(0x2b8C4583331635355CD6d687B2884518ECA240b2);
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

        anc.setFarmCore(address(farmCore));
        anc.setAllowlist(address(liquidityManager), true);

        farmReferral.setFarmCore((farmCore));
        farmNode.setFarmCore((farmCore));
        farmToday.setFarmCore((farmCore));
        liquidityManager.setFarmCore(address(farmCore));

        // FarmCore _farmCore,
        // FarmNode _farmNode,
        // FarmReferral _farmReferral,
        // FarmToday _farmToday
        farmView = new FarmView(farmCore, farmNode, farmReferral, farmToday);
        vm.stopBroadcast();

        console.log("Tether deployed at:", address(USDT));
        console.log("Anc deployed at:",address(anc));
        console.log("Anc`s pancake pair:", anc.pancakePair());

        console.log("LiquidityManager deployed at:",address(liquidityManager));
        console.log("FarmReferral deployed at:",address(farmReferral));
        console.log("FarmToday view deployed at:",address(farmToday));
        console.log("FarmNode deployed at:",address(farmNode));
        console.log("FarmCore deployed at:",address(farmCore));
        console.log("FarmView deployed at:",address(farmView));
    }
}