// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";

import {FarmCore} from "../src/FarmCore.sol";
import {FarmNode} from "../src/FarmNode.sol";
import {FarmReferral} from "../src/FarmReferral.sol";
import {FarmToday} from "../src/FarmToday.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {Process} from "../src/libraries/Process.sol";

import {Anc} from "../src/Anc.sol";

contract FarmCoreTest is Test{
    Anc anc;
    address initialRecipient;
    address recipient;
    // address _community,
    // address _buyBack,
    // address _USDT

    FarmCore farmCore;
    address admin;
    address community;
    address buyBack;
    address USDT;
    // address ANC;
    FarmReferral farmReferral;
    FarmNode farmNode;
    FarmToday farmToday;
    LiquidityManager liquidityManager;
    // address _USDT,
    // address _tokenAnc
    address initialCode;

    address user;
    address owner;
    address uniswapV2Router;
    

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("rpc_url"));
        vm.selectFork(mainnetFork);

        //mainnet address
        uniswapV2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        USDT = address(0x55d398326f99059fF775485246999027B3197955);

        //create address
        initialRecipient = address(1);
        admin = address(2);
        community = address(3);
        buyBack = address(4);
        initialCode = address(5);
        user = address(6);
        owner = address(7);
        recipient = address(8);

        vm.startPrank(owner);
        //部署代币
        anc = new Anc(initialRecipient, recipient, community, buyBack, USDT);

        //部署farmNode
        FarmNode farmNodeImpl = new FarmNode();
        ERC1967Proxy farmNodeProxy = new ERC1967Proxy(
            address(farmNodeImpl),
            abi.encodeCall(farmNodeImpl.initialize,())
        );
        farmNode = FarmNode(payable(address(farmNodeProxy)));

        //部署farmReferral
        FarmReferral farmReferralImpl = new FarmReferral();
        ERC1967Proxy farmReferralProxy = new ERC1967Proxy(
            address(farmReferralImpl),
            abi.encodeCall(farmReferralImpl.initialize,(initialCode))
        );
        farmReferral = FarmReferral(payable(address(farmReferralProxy)));

        //部署farmToday
        FarmToday farmTodayImpl = new FarmToday();
        ERC1967Proxy farmTodayProxy = new ERC1967Proxy(
            address(farmTodayImpl),
            abi.encodeCall(farmTodayImpl.initialize,())
        );
        farmToday = FarmToday(payable(address(farmTodayProxy)));

        //部署liquidityManager
        LiquidityManager liquidityManagerImpl = new LiquidityManager();
        ERC1967Proxy liquidityManagerProxy = new ERC1967Proxy(
            address(liquidityManagerImpl),
            abi.encodeCall(liquidityManagerImpl.initialize,(USDT, address(anc)))
        );
        liquidityManager = LiquidityManager(payable(address(liquidityManagerProxy)));

        //部署farmCore
        FarmCore farmCoreImpl = new FarmCore();
        ERC1967Proxy farmCoreProxy = new ERC1967Proxy(
            address(farmCoreImpl),
            abi.encodeCall(farmCoreImpl.initialize,(
                admin,
                community,
                buyBack,
                USDT,
                address(anc),
                farmReferral,
                farmNode,
                farmToday,
                liquidityManager
            ))
        );
        farmCore = FarmCore(payable(address(farmCoreProxy)));

        //给配套合约设置farmCore地址
        farmNode.setFarmCore(farmCore);
        farmReferral.setFarmCore(farmCore);
        farmToday.setFarmCore(farmCore);
        liquidityManager.setFarmCore(address(farmCore));
        //anc给farmCore设置白名单
        anc.setFarmCore(address(farmCore));
        anc.setAllowlist(address(liquidityManager), true);
        vm.stopPrank();

        //添加流动性
        addLiquidity();
    }

    function addLiquidity() internal{
        deal(USDT, initialRecipient, 10000e18);
        vm.startPrank(initialRecipient);
        IERC20(USDT).approve(uniswapV2Router, 10000e18);
        anc.approve(uniswapV2Router, 10000e18);

        IUniswapV2Router02(uniswapV2Router).addLiquidity(
            USDT, 
            address(anc), 
            10000e18, 
            10000e18, 
            0, 
            0, 
            initialRecipient, 
            block.timestamp + 30
        );
        vm.stopPrank();

    }

    function test_referral(address _recommender, address _user) internal {
        vm.startPrank(_user);
        farmCore.referral(_recommender);
        vm.stopPrank();
    }

    function test_stake_utils(address _user, uint256 _amount) internal{
        vm.startPrank(_user);
        deal(USDT, _user, _amount);
        IERC20(USDT).approve(address(farmCore), _amount);
        farmCore.stake(_amount);
        vm.stopPrank();
    }

    function test_redeem_utils(address _user, uint256 _idx) internal{
        vm.startPrank(_user);
        farmCore.redeem(_idx);
        vm.stopPrank();
    }

    //测试目的
    //1.小区业绩测试
    //2.奖励分发测试两代
    function test_stake() public {
        test_referral(initialCode, user);
        test_stake_utils(user, 100e18);

        address user1 = address(10);
        test_referral(initialCode, user1);
        test_stake_utils(user1, 100e18);

        address user2 = address(11);
        test_referral(user, user2);
        test_stake_utils(user2, 100e18);

        address[] memory addrs = farmReferral.getDirectReferralAddrs(initialCode);
        assertEq(addrs.length, 2);
        (
            ,
            uint256 usdtAward,
            uint256 ancAward,
            uint256 overallPerformance,
            uint256 effectivePerformance,
            uint256 referralNum
        ) = farmReferral.referralInfo(initialCode);
        assertEq(usdtAward, 25e18);
        assertEq(ancAward, 0);
        assertEq(overallPerformance, 66e18 * 3);
        assertEq(effectivePerformance, 66e18);
        assertEq(referralNum, 3);
    }
    //测试目的
    //1.大区是50000e18
    //2.测试2万usdt达标用户是否添加到usdtRankAddrs
    //3.测试5万usdt达标用户是否添加到ancRankAddrs
    function test_rank_update() public {
        uint256[5] memory amounts = [
            uint256(50000e18),
            uint256(20000e18),
            uint256(20000e18),
            uint256(20000e18),
            uint256(20000e18)
        ];

        for(uint i=0; i<amounts.length; i++){
            address u = address(uint160(10 + i));
            test_referral(initialCode, u);
            test_stake_utils(u, amounts[i]);
        }
        (
            ,uint256 usdtAward,,
            uint256 overallPerformance,
            uint256 effectivePerformance,
        ) = farmReferral.referralInfo(initialCode); 
    
        assertEq(overallPerformance, 130000e18 * 66 / 100);
        assertEq(effectivePerformance, 80000e18 * 66 / 100);
        assertEq(usdtAward, 13000e18);
        address[] memory usdtRankAddrs = farmReferral.getUsdtRankAddrs();
        address[] memory ancRankAddrs = farmReferral.getAncRankAddrs();
        assertEq(usdtRankAddrs[0], initialCode);
        assertEq(ancRankAddrs[0], initialCode);
    }

    //测试目的:20代推荐是否会崩溃
    function test_20Hierarchy() public {
        uint256 amount = 100e18;
        address[20] memory u;
        for(uint i=0; i<20; i++){
            u[i] = address(uint160(10+i));
        }

        for(uint i=0; i<20; i++){
            if(i==0) test_referral(initialCode, u[i]);
            else test_referral(u[i-1], u[i]);
            test_stake_utils(u[i], amount);
        }
        (,,,,,uint256 referralNum) = farmReferral.referralInfo(initialCode); 
        assertEq(referralNum, 20);
    }
    
    //测试目的
    //1.扣减业绩
    //2.用户赎回anc到账数据
    //3.更新2万usdt达标用户地址
    //4.更新5万usdt达标用户地址
    function test_redeem() public{
        address user1 = address(10);
        address user2 = address(11);
        address user3 = address(12);
        address user4 = address(13);
        address user5 = address(14);

        uint256 amount = 20000e18;
        test_referral(initialCode, user1);
        test_referral(initialCode, user2);
        test_referral(initialCode, user3);
        test_referral(initialCode, user4);
        test_referral(initialCode, user5);

        test_stake_utils(user1, amount);
        test_stake_utils(user2, amount);
        test_stake_utils(user3, amount);
        test_stake_utils(user4, amount);
        test_stake_utils(user5, amount);

        assertEq(80000e18 * 66 / 100, farmReferral.totalAncRankEffectivePerformance());
        assertEq(80000e18 * 66 / 100, farmReferral.totalUsdtRankEffectivePerformance());

        test_redeem_utils(user1, 0);
        assertEq(anc.balanceOf(user1), 0);
        assert(IERC20(USDT).balanceOf(user1) > 10000e18);

        (
            ,uint256 usdtAward,,
            uint256 overallPerformance,
            uint256 effectivePerformance,
        ) = farmReferral.referralInfo(initialCode); 
    
        assertEq(overallPerformance, 80000e18 * 66 / 100);
        assertEq(effectivePerformance, 60000e18 * 66 / 100);
        assertEq(usdtAward, 10000e18);

        address[] memory usdtRankAddrs = farmReferral.getUsdtRankAddrs();
        address[] memory ancRankAddrs = farmReferral.getAncRankAddrs();
        assertEq(usdtRankAddrs[0], initialCode);
        assertEq(ancRankAddrs.length, 0);     
        assertEq(0, farmReferral.totalAncRankEffectivePerformance());
        assertEq(60000e18 * 66 / 100, farmReferral.totalUsdtRankEffectivePerformance());   

    }

    //收益部分,计算5万usdt达标anc收益
    function test_rank_ancAward() public {
        address user1 = address(10);
        test_referral(initialCode, user);
        test_referral(initialCode, user1);
        uint256 stakeAmount = 80000e18;
        test_stake_utils(user, stakeAmount);
        test_stake_utils(user1, stakeAmount);

        (
            ,,,
            uint256 overallPerformance,
            uint256 effectivePerformance,
        ) = farmReferral.referralInfo(initialCode); 

        assertEq(overallPerformance, stakeAmount * 66 / 100 * 2);
        assertEq(effectivePerformance, stakeAmount * 66 / 100);
        assertEq(anc.latestBurnTime(), block.timestamp);

        vm.warp(block.timestamp + 1 days);
        //10000e18 * 3% * 90% = ancAward * 78%
        //300 30(wallet) 270 * 给合约

        uint256 totalAmount = anc.balanceOf(anc.pancakePair());
        uint256 totalIssue = totalAmount * 3 / 100;
        uint256 toWallet = totalIssue * 10 / 100;
        uint256 toAward = (totalIssue - toWallet) * 2005 / 10000;
        uint256 toStaking = toAward * 78 / 100;
        uint256 toRank = toAward - toStaking;
        console.log("toRank:", toRank);

        farmCore.issueAncRankAward();

        (uint256 ancAward,) = farmCore.getUserTruthAward(initialCode);
        console.log("initialCode award anc:",ancAward);
        vm.startPrank(initialCode);
        farmCore.claimAnc();
        vm.stopPrank();
        (uint256 ancAward0,) = farmCore.getUserTruthAward(initialCode);
        assert(ancAward0 == 0);
        
    }
    
    //收益部分，质押anc得到的收益
    function test_staking_ancAward() public {
        address user1 = address(10);
        test_referral(initialCode, user);
        test_referral(initialCode, user1);
        uint256 stakeAmount = 100e18;
        test_stake_utils(user, stakeAmount);
        test_stake_utils(user1, stakeAmount);

        // uint256 totalAmount = anc.balanceOf(anc.pancakePair());
        // uint256 totalIssue = totalAmount * 3 / 100;
        // uint256 toWallet = totalIssue * 10 / 100;
        // uint256 toAward = (totalIssue - toWallet) * 2005 / 10000;
        // uint256 toStaking = toAward * 78 / 100;

        // uint256 toStakingOneHalf = toStaking / 2;

        vm.warp(block.timestamp + 1 days);
        farmCore.issueAncRankAward();        

        (uint256 ancAward0,) = farmCore.getUserTruthAward(user);
        (uint256 ancAward1,) = farmCore.getUserTruthAward(user1);
        assertEq(ancAward0, ancAward1);

        vm.startPrank(user);
        farmCore.claimAnc();
        vm.stopPrank();
        (uint256 ancAward2,) = farmCore.getUserTruthAward(user);
        assert(ancAward2 == 0);
    }

    //收益部分，层级收益层级奖励
    function test_hierarchy_award_detailed() public {
        uint256 amountStake = 100e18;

        // 直推 10 个人
        for (uint i = 0; i < 10; i++) {
            address u = address(uint160(10 + i));
            test_referral(initialCode, u);
            test_stake_utils(u, amountStake);
        }

        // 下面邀请 20 层
        address[20] memory addrs;
        for (uint i = 0; i < 20; i++) {
            addrs[i] = address(uint160(30 + i));
            if (i == 0) test_referral(initialCode, addrs[i]);
            else test_referral(addrs[i - 1], addrs[i]);
            test_stake_utils(addrs[i], amountStake);

        }

        // 最终奖励
        (,uint256 usdtAward1,,,,) = farmReferral.referralInfo(initialCode); 
        assert(usdtAward1 == 124e18);
    }

    //测试管理员方法
    function test_add_node_forAdmin() public {
        test_referral(initialCode, user);
        address[] memory users = new address[](1);
        users[0] = user;
        vm.startPrank(admin);
        farmCore.addNodeForAdmin(Process.NodeType.SMALL, users, 100e18);
        vm.stopPrank();
        uint256 totalStake = farmCore.totalStakeValidUsdt();
        assertEq(totalStake, farmCore.nodePrice(Process.NodeType.SMALL) * 66 / 100);

 
        (Process.NodeType nodeType, uint256 stakingUsdt,,,,) = farmCore.userInfo(user);
        assert(nodeType == Process.NodeType.SMALL);
        assert(totalStake == stakingUsdt);

        address[] memory nodeAddrs = farmNode.getNodeAddrs(Process.NodeType.SMALL);
        assert(nodeAddrs[0] == user);

        (
            ,
            uint256 usdtReferralAward,,
            uint256 overallPerformance,
            uint256 effectivePerformance,
            uint256 referralNum
        ) = farmReferral.referralInfo(initialCode);

        assertEq(usdtReferralAward, 0);
        assert(overallPerformance == totalStake);
        assertEq(effectivePerformance, 0);
        assert(referralNum == 1);
    }

}

