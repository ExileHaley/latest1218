// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Djsc} from "../src/Djsc.sol";
import {Djs}  from "../src/Djs.sol";

import {Finance}  from "../src/Finance.sol";
import {LiquidityManager}  from "../src/LiquidityManager.sol";
import {NodeDividends}  from "../src/NodeDividends.sol";

contract DeployScript is Script {
    Djsc public djsc;
    address public technology;
    address public foundation;
    address public marketingForDjsc;
    address public pot;

    address public sellFee;
    address public buyFee;
    address public profitFee;
    

    Djs  public djs;
    address public initialRecipient;
    address public marketingForDjs;
    // address public nodeDividends;
    address public wallet;


    Finance public finance;
    address admin;
    address initialCode;
    address djsv1;
    // address nodeDividends;
    // address liquidityManager;

    NodeDividends public nodeDividends;
    address nfts;
    // address token;

    LiquidityManager public liquidityManager;
    // address _token;
    // address _subToken;
    
    //djs:address _initialRecipient, address _marketing, address _wallet setNode
    //djsc:address[4] memory addrs, address _sellFee, address _buyFee, address _profitFee
    //Finance:address _admin,address _initialCode,address _djsv1,address _nodeDividends,address _liquidityManager
    //LiquidityManager:address _token,address _subToken setStaking
    //NodeDividends:address _nfts,address _token setStaking
    function setUp() public {
        initialCode = 0x681be3bA6D85Ff7Ed459372a3aEEEdf43c7Aa37d;
        djsv1 = 0x0e7f2f2155199E2606Ce24C9b2C5C7C3D5960116;
        nfts = 0x20D872c41B1373FC9772cbda51609359caFB3748;


        //djsc param init
        technology = address(0x6f83852EA96F41Cb1a71a66730Ca4F021baB5A00);
        foundation = address(0x61940dc64161a8fC9672C8E53e5784f13143ff33);
        marketingForDjsc = address(0x81B2d8cbCd1Aceda4CbCbDbD976b2C2ca2591489);
        pot = address(0x7364032cE6AAbB49721DB4dC1d7a609CA4Bf3d2F);

        sellFee = address(0xf3e1Ff26DDC4E7d19a185D662e46EFe88ad469EB);
        buyFee = address(0x5Cca5A3e2Eef835417A571B28822B1e991b3B246);
        profitFee = address(0xA751cD53a795d42c52444A5DA5503949D706500A);

        //djs parm init 
        initialRecipient = address(0xf93BbB196a961F7e8B54900DBb38e84a6d1fC937);
        marketingForDjs = address(0x03C747ffBb61605390d2f275E61a734A9d329e04);
        // address public nodeDividends;
        wallet = address(0x4cDaC2E5C5125F5D6381109cd14756F05282e59d);

        //finance param init
        admin = address(0xB791b9E7a13991371462c7A76628Ac79777e3165);
    }

    function run() public {
        
        vm.startBroadcast();
        address[4] memory addrs = [technology, foundation, marketingForDjsc, pot];
        djsc = new Djsc(addrs, sellFee, buyFee, profitFee);
        djs = new Djs(initialRecipient, marketingForDjs, wallet);

        //deploy nodeDividends
        NodeDividends nodeImpl = new NodeDividends();
        ERC1967Proxy nodeProxy = new ERC1967Proxy(
            address(nodeImpl),
            abi.encodeCall(nodeImpl.initialize,(nfts, address(djs)))
        );
        nodeDividends = NodeDividends(payable(address(nodeProxy)));

        //deploy liquidityManager
        LiquidityManager liquidityImpl = new LiquidityManager();
        ERC1967Proxy liquidityProxy = new ERC1967Proxy(
            address(liquidityImpl),
            abi.encodeCall(liquidityImpl.initialize,(address(djs), address(djsc)))
        );
        liquidityManager = LiquidityManager(payable(address(liquidityProxy)));

        //deploy finance
        Finance financeImpl = new Finance();
        ERC1967Proxy financeProxy = new ERC1967Proxy(
            address(financeImpl),
            abi.encodeCall(financeImpl.initialize,(admin, initialCode, djsv1, address(nodeDividends), address(liquidityManager)))
        );
        finance = Finance(payable(address(financeProxy)));


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
        //token transfer owner
        djs.transferOwnership(initialRecipient);
        djsc.transferOwnership(pot);
        vm.stopBroadcast();

        console.log("Djs deployed at:",address(djs));
        console.log("Djsc deployed at:",address(djsc));

        console.log("LiquidityManager deployed at:",address(liquidityManager));
        console.log("NodeDividends deployed at:",address(nodeDividends));
        console.log("Finance deployed at:",address(finance));
    }

}

// djsc的地址:0xC80F1014421dc1504843Fc4966646A1bC3a22f17

// 技术地址 0x6f83852EA96F41Cb1a71a66730Ca4F021baB5A00
// 基金会地址 0x61940dc64161a8fC9672C8E53e5784f13143ff33
// 营销地址 0x81B2d8cbCd1Aceda4CbCbDbD976b2C2ca2591489
// 底池地址 0x7364032cE6AAbB49721DB4dC1d7a609CA4Bf3d2F
// 卖出手续费地址 0xf3e1Ff26DDC4E7d19a185D662e46EFe88ad469EB
// 买入手续费地址 0x5Cca5A3e2Eef835417A571B28822B1e991b3B246
// 盈利税地址 0xA751cD53a795d42c52444A5DA5503949D706500A

// djs的地址 0xad7DDeE33153860D2169e023698e78C59CeD7550
// 代币接收者地址 0xf93BbB196a961F7e8B54900DBb38e84a6d1fC937
// 营销地址 0x03C747ffBb61605390d2f275E61a734A9d329e04
// 盈利税5%的地址(用于购买子币的部分手动去买) 0x4cDaC2E5C5125F5D6381109cd14756F05282e59d

// 理财合约的地址 0xb791b9e7a13991371462c7a76628ac79777e3165
// 管理员地址 0xb791b9e7a13991371462c7a76628ac79777e3165