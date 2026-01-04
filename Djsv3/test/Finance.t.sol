// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

import {Djs} from "../src/Djs.sol";
import {Djsc} from "../src/Djsc.sol";


contract FinanceTest is Test{
    // address _admin,
    // address _initialCode,
    // address _djsv1,
    // address _nodeDividends,
    // address _liquidityManager
    Finance public finance;
    address public admin;
    address public initialCode;
    address public recipientForBurn;

    // address _nfts,
    // address _token
    NodeDividends public nodeDividends;
    address       public nfts;
    Djs           public djs;

    // address _token,
    // address _subToken
    LiquidityManager public liquidityManager;
    Djsc             public djsc;

    address public technology;
    address public foundation;
    address public marketingForDjsc;
    address public pot;

    address public sellFee;
    address public buyFee;
    address public profitFee;

    //djs parm init 
    address public initialRecipient;
    address public marketingForDjs;
    // address public nodeDividends;
    address public wallet;

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

        initialCode = address(1);
        recipientForBurn = address(2);
        owner = address(3);
        user  = address(4);

        //deploy
        vm.startPrank(owner);
        djs = new Djs(initialRecipient, marketingForDjs, wallet);
        djs.setTradingOpen(true);
        address[4] memory addrs = [technology, foundation, marketingForDjsc, pot];
        djsc = new Djsc(addrs, sellFee, buyFee, profitFee);
        
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

        vm.stopPrank();

        vm.startPrank(foundation);
        djsc.transfer(initialRecipient, 10000e18);
        vm.stopPrank();
        //add liquidity
        addLiquidty(initialRecipient, address(djs));
        addLiquidty(initialRecipient, address(djsc));
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

        (,Process.Level level0,,,,,,) = finance.referralInfo(user);
        assertEq(uint256(level0), uint256(Process.Level.V5));

        address[10] memory v5ReferralsForUser1;
        for(uint i=0; i<9; i++){
            address u = address(uint160(10 + i));
            v5ReferralsForUser1[i] = u;
            test_stake_utils(user1, u, 400000e18);
        }
        (,Process.Level level1,,,,,,)  = finance.referralInfo(user1);
        assertEq(uint256(level1), uint256(Process.Level.V5));


        address[10] memory v5ReferralsForUser2;
        for(uint i=0; i<9; i++){
            address u = address(uint160(30 + i));
            v5ReferralsForUser2[i] = u;
            test_stake_utils(user2, u, 400000e18);
        }
        (,Process.Level level2,,,,,,)  = finance.referralInfo(user2);
        assertEq(uint256(level2), uint256(Process.Level.V5));


        address user3 = address(100);
        test_stake_utils(user1, user3, 100e18);
        (,Process.Level level3,,,,,,)  = finance.referralInfo(user);
        // console.log("user level:",uint256(level2));
        assertEq(uint256(level3), uint256(Process.Level.SHARE));
    }


    function test_directAward() public {
        uint256 beforeUsdtAmount = IERC20(USDT).balanceOf(recipientForBurn);
        test_stake_utils(initialCode, user, 100e18);
        address user1 = address(10);
        test_stake_utils(user, user1, 100e18);
        vm.warp(block.timestamp + 10 days);

        uint256 stakingAward = finance.getUserStakingAward(user1);
        uint256 totalAward = finance.getUserAward(user1);
        assertEq(stakingAward, totalAward);

        vm.startPrank(user1);
        finance.claim();
        vm.stopPrank();
        (,,,,uint256 referralAward,,,)  = finance.referralInfo(user);
        assertEq(stakingAward * 10 / 100, referralAward);

        (,,,,uint256 referralAward1,,,)  = finance.referralInfo(initialCode);
        assertEq(stakingAward * 50 / 100, referralAward1);

        uint256 afterUsdtAmount = IERC20(USDT).balanceOf(recipientForBurn);
        assertEq(beforeUsdtAmount + 7e18, afterUsdtAmount);
    }

    function test_awardForLevel() public {
        test_stake_utils(initialCode, user, 100e18);
        address user1 = address(9);
        test_stake_utils(user, user1, 100e18);

        address[4] memory v1ReferralsForUser;
        for(uint i=0; i<4; i++){
            address u = address(uint160(10 + i));
            v1ReferralsForUser[i] = u;
            test_stake_utils(user, u, 3000e18);
        }

        (,Process.Level level0,,,,,,) = finance.referralInfo(user);
        assertEq(uint256(level0), uint256(Process.Level.V1));


        address[4] memory v1ReferralsForUser1;
        for(uint i=0; i<4; i++){
            address u = address(uint160(20 + i));
            v1ReferralsForUser1[i] = u;
            test_stake_utils(user1, u, 3000e18);
        }
        (,Process.Level level1,,,,,,) = finance.referralInfo(user1);
        assertEq(uint256(level1), uint256(Process.Level.V1));

        address user2 = address(100);
        test_stake_utils(user1, user2, 100e18);

        vm.warp(block.timestamp + 10 days);
        uint256 stakingAward = finance.getUserStakingAward(user2);
        uint256 totalAward = finance.getUserAward(user2);
        assertEq(stakingAward, totalAward);
        vm.startPrank(user2);
        finance.claim();
        vm.stopPrank();

        (,,,,uint256 referralAward0,,,)  = finance.referralInfo(user1);
        assertEq(stakingAward * 20 / 100, referralAward0);

        (,,,,uint256 referralAward1,,,)  = finance.referralInfo(user);
        assertEq(0, referralAward1);

        (,,,,uint256 referralAward2,,,)  = finance.referralInfo(initialCode);
        assertEq(stakingAward * 40 / 100, referralAward2);
    }

    function test_awardForShare() public {
        test_upgrade_to_share();
        address[] memory shareAddrs = finance.getShareAddrs();
        assertEq(shareAddrs.length, 1);

        address user1000 = address(10000);
        test_stake_utils(initialCode, user1000, 100e18);

        vm.warp(block.timestamp + 10 days);
        uint256 stakingAward = finance.getUserStakingAward(user1000);
        vm.startPrank(user1000);
        finance.claim();
        vm.stopPrank();

        uint256 user1000Award = finance.getUserAward(user1000);
        assertEq(user1000Award, 0);

        (,,,,,uint256 shareAward,,)  = finance.referralInfo(user);
        assertEq(stakingAward * 10 / 100, shareAward);
    }

    function test_staking_referral_shareAward() public {
        //user升级到了share等级
        test_upgrade_to_share();
        address user1000 = address(10000);
        test_stake_utils(initialCode, user1000, 100e18);

        vm.warp(block.timestamp + 10 days);
        uint256 stakingAward = finance.getUserStakingAward(user1000);
        vm.startPrank(user1000);
        finance.claim();
        vm.stopPrank();

        
        uint256 totalAward = stakingAward * 10 / 100 + stakingAward;
        assertEq(totalAward, finance.getUserAward(user));

    }

}