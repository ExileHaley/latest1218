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
        djs = new Djs(initialRecipient, marketingForDjs, wallet, USDT);
        djs.setTradingOpen(true);
        address[4] memory addrs = [technology, foundation, marketingForDjsc, pot];
        djsc = new Djsc(addrs, sellFee, buyFee, USDT);
        
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


    function test_referralAward_cutOff() public {
        address user1 = address(5);
        address user2 = address(6);

        uint256 stakeAmount = 10000e18;

        /**
        * 1️⃣ 建立推荐关系
        * initialCode -> user -> user1 -> user2
        */
        test_stake_utils(initialCode, user, 100e18);
        test_stake_utils(user, user1, 100e18);


        /**
        * 2️⃣ user 升级到 V1
        * 3 次直推 + 3 * 10000 performance
        */
        test_stake_utils(user, address(10), stakeAmount);
        test_stake_utils(user, address(11), stakeAmount);
        test_stake_utils(user, address(12), stakeAmount);

        // assertEq(uint8(finance.referralInfo(user).level), uint8(Process.Level.V1));
        (,Process.Level levelUser,,,,,,) = finance.referralInfo(user);
        assertEq(uint8(levelUser), uint8(Process.Level.V1));

        /**
        * 3️⃣ user1 升级到 V2
        * 4 次直推 + 5 * 10000 performance
        */
        test_stake_utils(user1, address(13), stakeAmount);
        test_stake_utils(user1, address(14), stakeAmount);
        test_stake_utils(user1, address(15), stakeAmount);
        test_stake_utils(user1, address(16), stakeAmount);
        test_stake_utils(user1, address(17), stakeAmount);

        // address recommender;    //推荐人地址
        // Level   level;          //级别
        // uint256 referralNum;    //有效邀请人数
        // uint256 performance;    //邀请总业绩
        // uint256 referralAward;  //邀请奖励
        // uint256 shareAward;     //share等级升级前的负债，避免多给
        // uint256 subCoinQuota;   //子币额度
        // bool    isMigration;    //是否映射旧版本邀请关系
        (,Process.Level levelUser1,,,,,,) = finance.referralInfo(user1);
        assertEq(uint8(levelUser1), uint8(Process.Level.V2));

        /**
        * 4️⃣ user2 stake
        */
        test_stake_utils(user1, user2, stakeAmount);

        /**
        * 5️⃣ 推进时间，产生 staking 收益
        */
        vm.warp(block.timestamp + 10 days);
        uint256 stakingReward = finance.getUserStakingAward(user2);
        /**
        * 6️⃣ user2 claim（触发 referral reward 分发）
        */
        vm.startPrank(user2);
        finance.claim();
        vm.stopPrank();

        /**
        * 7️⃣ 校验奖励
        */
        // uint256 stakingUsdt;        //质押数量
        // uint256 stakingTime;        //质押时间
        // uint256 pendingDividend;    //质押收益结余，计算使用
        // uint256 pendingBonus;       //邀请奖励+share奖励，计算使用
        // uint256 extracted;          //已提取收益   
        // bool    addSubCoinQuota;    //大于1000u质押的用户有且只有给一次10U子币额度
        (,,,uint256 pendingBonusUser1,,) = finance.userInfo(user1);
        (,,,uint256 pendingBonusUser,,) = finance.userInfo(user);


        // user1: V1 + V2 = 20% + direct 10% = 30%
        uint256 expectedUser1 =
            stakingReward * 30 / 100;

        // user: 不应拿到 V1 的 10%
        uint256 expectedUser = 0;

        // assertApproxEqAbs(user1Bonus, expectedUser1, 1);
        assertEq(pendingBonusUser1, expectedUser1);
        assertEq(pendingBonusUser, expectedUser);
    }


}