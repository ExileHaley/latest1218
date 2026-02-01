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

//     代币接收地址0x6772718B1db9888CFfc3B939A2f4742A30A3b90d
//         每日销毁10%Anc接收地址0xfD35119FCd7ecBC0cc56f97619480216F0c0B832
//         社区20% usdt接收地址、0x0e820636CA2317828789115564F530192F077cBb
//         保护币价下跌usdt接收地址0xF0747A9f5D583f1ADd453d7e2E1602023e9291E7
//         添加节点管理员地址0x798a46C31fdb255FaCB2E05441B4a754Fb0B967C
//         首码地址
// 0x9e343C0e62a57251A926cee221d3A1FDA1b2f999
    function setUp() public {
        initialRecipient = address(0x6772718B1db9888CFfc3B939A2f4742A30A3b90d);
        recipient = address(0xfD35119FCd7ecBC0cc56f97619480216F0c0B832);
        community = address(0x0e820636CA2317828789115564F530192F077cBb);
        buyBack = address(0xF0747A9f5D583f1ADd453d7e2E1602023e9291E7);
        admin = address(0xCf8f660e4de36a5c84A95104deC347b5891dD963);
        initialCode = address(0x9e343C0e62a57251A926cee221d3A1FDA1b2f999);
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