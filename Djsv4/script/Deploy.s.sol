// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Djsc} from "../src/Djsc.sol";
import {Djs}  from "../src/Djs.sol";

import {Finance}  from "../src/Finance.sol";
import {FinanceView} from "../src/FinanceView.sol";
import {LiquidityManager}  from "../src/LiquidityManager.sol";
import {NodeDividends}  from "../src/NodeDividends.sol";

// import {Tether} from "../src/mock/Tether.sol";

contract DeployScript is Script {
    // Tether  public tether;
    address public USDT;
    Djsc    public djsc;
    address public technology;
    address public foundation;
    address public marketingForDjsc;
    address public pot;

    address public sellFee;
    address public profitFee;
    

    Djs  public djs;
    address public initialRecipient;
    address public sellAndProfit;
    // address public nodeDividends;
    address public walletForProfit;


    Finance public finance;
    FinanceView public financeView;
    address admin;
    address initialCode;
    address djsv1;
    address recipientForBurn;


    NodeDividends public nodeDividends;
    address nfts;
    // address token;

    LiquidityManager public liquidityManager;
    
// 0x43aB376436D4BA650b1469e19C77755574c2eD9C(技术)
// 0x231b16Ad368473c2a9413d6C77a1da1f250289d1(基金会)
// 0xbbDc68b0214D44881F8a247F6c3651485D457709(营销)
// 0xE56A26daCD6dE5abEf31363419f739cc8cE187fB(9000万接收地址)
// 0x001915F965187991F6C381A35653622217abc07A(子币卖出手续费地址)
// 0x60131ea383100b10F94dcE6fCbc03194b667676D(母币接收地址)
// 0x57B6951881daD04AC09FF9ff70960CD3E9F2E08d(卖出手续费和盈利税接收地址手续费5%+盈利税15%)
// 0x7910F5E702Cded0eb0c434D85C9eAE062d3F6E85(卖出盈利税接收地址5%)
// 0x00A4cfF6dD280d3ed04a765Fd2771F4478598851(充值1%提现5u兑换3%)
    function setUp() public {
        initialCode = 0x681be3bA6D85Ff7Ed459372a3aEEEdf43c7Aa37d;
        djsv1 = 0x0e7f2f2155199E2606Ce24C9b2C5C7C3D5960116;
        nfts = 0x20D872c41B1373FC9772cbda51609359caFB3748;

        //djsc param init
        technology = address(0x43aB376436D4BA650b1469e19C77755574c2eD9C);
        foundation = address(0x231b16Ad368473c2a9413d6C77a1da1f250289d1);
        marketingForDjsc = address(0xbbDc68b0214D44881F8a247F6c3651485D457709);
        pot = address(0xE56A26daCD6dE5abEf31363419f739cc8cE187fB);
        sellFee = address(0x001915F965187991F6C381A35653622217abc07A);

        //djs parm init 
        initialRecipient = address(0x60131ea383100b10F94dcE6fCbc03194b667676D);
        sellAndProfit = address(0x57B6951881daD04AC09FF9ff70960CD3E9F2E08d);
        walletForProfit = address(0x7910F5E702Cded0eb0c434D85C9eAE062d3F6E85);

        //finance param init
        admin = address(0xB791b9E7a13991371462c7A76628Ac79777e3165);
        recipientForBurn = address(0x00A4cfF6dD280d3ed04a765Fd2771F4478598851);

        USDT = address(0x55d398326f99059fF775485246999027B3197955);
    }

    function run() public {
        vm.startBroadcast();
        // tether = new Tether(initialRecipient);
        djs = new Djs(initialRecipient, sellAndProfit, walletForProfit, USDT);
        address[4] memory addrs = [technology, foundation, marketingForDjsc, pot];
        djsc = new Djsc(addrs, sellFee, USDT);

        //deploy nodeDividends
        NodeDividends nodeImpl = new NodeDividends();
        ERC1967Proxy nodeProxy = new ERC1967Proxy(
            address(nodeImpl),
            abi.encodeCall(nodeImpl.initialize,(USDT, nfts, address(djs)))
        );
        nodeDividends = NodeDividends(payable(address(nodeProxy)));

        //deploy liquidityManager
        LiquidityManager liquidityImpl = new LiquidityManager();
        ERC1967Proxy liquidityProxy = new ERC1967Proxy(
            address(liquidityImpl),
            abi.encodeCall(liquidityImpl.initialize,(USDT, address(djs), address(djsc), recipientForBurn))
        );
        liquidityManager = LiquidityManager(payable(address(liquidityProxy)));
        
        //deploy finance
        Finance financeImpl = new Finance();
        ERC1967Proxy financeProxy = new ERC1967Proxy(
            address(financeImpl),
            abi.encodeCall(financeImpl.initialize,(
                USDT, 
                admin, 
                initialCode, 
                djsv1, 
                address(nodeDividends), 
                address(liquidityManager),
                recipientForBurn
            ))
        );
        finance = Finance(payable(address(financeProxy)));

        //deploy finacneView
        financeView = new FinanceView(finance);

        //djs set node
        djs.setNodeDividends(address(nodeDividends));

        //liquidity set staking
        liquidityManager.setStaking(address(finance));

        //node set staking
        nodeDividends.setStaking(address(finance));

        //set allowlist
        address[] memory allows = new address[](1);
        allows[0] = address(liquidityManager);
        djs.setAllowlist(allows, true);
        djsc.setAllowlist(allows, true);

        //设置黑名单
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 516;
        tokenIds[1] = 517;
        tokenIds[2] = 518;
        tokenIds[3] = 870;

        nodeDividends.setBlacklist(tokenIds);

        //转移管理员
        djs.transferOwnership(initialRecipient);
        djsc.transferOwnership(pot);
        vm.stopBroadcast();

        assert(!djs.tradingOpen());

        // console.log("Tether deployed at:", address(tether));
        console.log("Djs deployed at:",address(djs));
        console.log("Djs`s pancake pair:", djs.pancakePair());
        console.log("Djsc deployed at:",address(djsc));
        console.log("Djsc`s pancake pair:", djsc.pancakePair());

        console.log("Finance deployed at:",address(finance));
        console.log("Finance view deployed at:",address(financeView));
        
        console.log("LiquidityManager deployed at:",address(liquidityManager));
        console.log("NodeDividends deployed at:",address(nodeDividends));
        
    }


}