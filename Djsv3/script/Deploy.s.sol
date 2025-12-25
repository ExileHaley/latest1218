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
        technology = address(0);
        foundation = address(0);
        marketingForDjsc = address(0);
        pot = address(0);

        sellFee = address(0);
        buyFee = address(0);
        profitFee = address(0);

        //djs parm init 
        initialRecipient = address(0);
        marketingForDjs = address(0);
        // address public nodeDividends;
        wallet = address(0);

        //finance param init
        admin = address(0);
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