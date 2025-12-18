// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";

import {Finance} from "../src/Finance.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {NodeDividends} from "../src/NodeDividends.sol";

import {Errors} from "../src/libraries/Errors.sol";
import {Process} from "../src/libraries/Process.sol";

import {Tdjs} from "../src/mock/Tdjs.sol";
import {Tdjsc} from "../src/mock/Tdjsc.sol";

contract FinanceTest is Test{
    // address _admin,
    // address _initialCode,
    // address _djsv1,
    // address _nodeDividends,
    // address _liquidityManager
    Finance public finance;
    address public admin;
    address public initialCode;

    // address _nfts,
    // address _token
    NodeDividends public nodeDividends;
    address       public nfts;
    Tdjs           public tdjs;

    // address _token,
    // address _subToken
    LiquidityManager public liquidityManager;
    Tdjsc             public tdjsc;


    address public owner;
    address public user;

    address public USDT;
    address public uniswapV2Router;
    address public djsv1;
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);

        //mainnet address
        uniswapV2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        USDT = address(0x55d398326f99059fF775485246999027B3197955);
        djsv1 = address(0x0e7f2f2155199E2606Ce24C9b2C5C7C3D5960116);
        nfts = address(0x20D872c41B1373FC9772cbda51609359caFB3748);

        initialCode = address(1);
        owner = address(2);
        user  = address(3);

        //deploy
        vm.startPrank(owner);
        //deploy token
        tdjs = new Tdjs(owner);
        tdjsc = new Tdjsc(owner);

        //deploy node dividends
        NodeDividends nodeImpl = new NodeDividends();
        ERC1967Proxy nodeProxy = new ERC1967Proxy(
            address(nodeImpl),
            abi.encodeCall(nodeImpl.initialize,(nfts, address(tdjs)))
        );
        nodeDividends = NodeDividends(payable(address(nodeProxy)));

        //deploy liquidity manager
        LiquidityManager liquidityImpl = new LiquidityManager();
        ERC1967Proxy liquidityProxy = new ERC1967Proxy(
            address(liquidityImpl),
            abi.encodeCall(liquidityImpl.initialize,(address(tdjs), address(tdjsc)))
        );
        liquidityManager = LiquidityManager(payable(address(liquidityProxy)));

        //deploy finance
        Finance financeImpl = new Finance();
        ERC1967Proxy financeProxy = new ERC1967Proxy(
            address(financeImpl),
            abi.encodeCall(financeImpl.initialize,(admin, initialCode, djsv1, address(nodeDividends), address(liquidityManager)))
        );
        finance = Finance(payable(address(financeProxy)));

        //set config
        nodeDividends.setStaking(address(finance));
        liquidityManager.setStaking(address(finance));

        //add liquidity
        addLiquidty(owner, address(tdjs));
        addLiquidty(owner, address(tdjsc));

        vm.stopPrank();
    }

    function addLiquidty(address _user, address _token) internal{
        deal(USDT, _user, 10000e18);
        vm.startPrank(_user);
        IERC20(USDT).approve(uniswapV2Router, 10000e18);
        IERC20(_token).approve(uniswapV2Router, 10000e18);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            USDT, 
            _token, 
            10000e18, 
            10000e18, 
            0, 
            0, 
            _user, 
            block.timestamp + 30
        );
        vm.stopPrank();
    }   

    function test_stake_utils(address _recommender, address _user, uint256 _amount) internal{
        vm.startPrank(_user);
        deal(USDT, _user, _amount);
        IERC20(USDT).approve(address(finance), _amount);
        finance.referral(_recommender);
        finance.stake(_amount);
        vm.stopPrank();
    }

    function test_upgrade_to_share() public  {
        test_stake_utils(initialCode, user, 100e18);
        address user1 = address(5);
        address user2 = address(6);
        test_stake_utils(user, user1, 100e18);
        test_stake_utils(user, user2, 100e18);

        address[10] memory v5ReferralsForUser;
        for(uint i=0; i<9; i++){
            address u = address(uint160(40 + i));
            v5ReferralsForUser[i] = u;
            test_stake_utils(user, u, 400000e18);
        }
        (Process.Level level0,,,,,) = finance.getUserInfoBasic(user);
        assertEq(uint256(level0), uint256(Process.Level.V5));

        address[10] memory v5ReferralsForUser1;
        for(uint i=0; i<9; i++){
            address u = address(uint160(10 + i));
            v5ReferralsForUser1[i] = u;
            test_stake_utils(user1, u, 400000e18);
        }
        (Process.Level level1,,,,,) = finance.getUserInfoBasic(user1);
        assertEq(uint256(level1), uint256(Process.Level.V5));


        address[10] memory v5ReferralsForUser2;
        for(uint i=0; i<9; i++){
            address u = address(uint160(30 + i));
            v5ReferralsForUser2[i] = u;
            test_stake_utils(user2, u, 400000e18);
        }
        (Process.Level level2,,,,,) = finance.getUserInfoBasic(user2);
        assertEq(uint256(level2), uint256(Process.Level.V5));


        address user3 = address(100);
        test_stake_utils(user1, user3, 100e18);
        (Process.Level level3,,,,,) = finance.getUserInfoBasic(user);
        // console.log("user level:",uint256(level2));
        assertEq(uint256(level3), uint256(Process.Level.SHARE));

    }

    function test_arward_v1_repeat() public {
        address user1 = address(10);
        address user2 = address(11);
        address user3 = address(12);
        // 让user升级到V1
        test_stake_utils(initialCode, user, 1000e18);
        test_stake_utils(user, user1, 4000e18);
        test_stake_utils(user, user2, 4000e18);
        test_stake_utils(user, user3, 4000e18);
        
        //让user1升级到V1
        address user4 = address(13);
        address user5 = address(14);
        address user6 = address(15);
        test_stake_utils(user1, user4, 4000e18);
        test_stake_utils(user1, user5, 4000e18);
        test_stake_utils(user1, user6, 4000e18);

        address user7 = address(16);
        test_stake_utils(user1, user7, 1000e18);
        (,Process.Level   level0,uint256 referralNum0,uint256 performance0,uint256 referralAward0,uint256 subCoinQuota0,,) = finance.referralInfo(user);
        assertEq(uint256(level0), uint256(Process.Level.V1));
        assertEq(referralNum0, 7);
        assertEq(performance0, 25000e18);
        assertEq(referralAward0, 1200e18);
        assertEq(subCoinQuota0, 100e18);
        // (,Process.Level   level1,uint256 referralNum1,uint256 performance1,uint256 referralAward1,uint256 subCoinQuota1,,) = finance.referralInfo(user1);
        // assertEq(uint256(level1), uint256(Process.Level.V1));
        // assertEq(referralNum1, 4);
        // assertEq(performance1, 13000e18);
        // assertEq(referralAward1, 100e18);
        // assertEq(subCoinQuota1, 100e18);
    }

}