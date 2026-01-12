// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";
import { Process } from "./libraries/Process.sol";

import { FarmReferral } from "../src/FarmReferral.sol";
import { FarmNode } from "../src/FarmNode.sol";
import { FarmToday } from "../src/FarmToday.sol";


interface IFarmReferral{
    function getRecommender(address user) external view returns(address); 
}

contract FarmCore is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    event Referrals(address recommender,address referred);
    event Staked(address user, uint256 amountUsdt, uint256 amountLiquidity);
    event Withdraw(address user, uint256 amountUsdt, uint256 amountAnc);
    using EnumerableSet for EnumerableSet.AddressSet;

    struct User {
        // ===== 基础身份 =====
        Process.NodeType nodeType;
        // ===== 质押 =====
        uint256 stakingUsdt;
        // === 奖励记录 ===
        uint256 extractedUsdt;
        uint256 extractedAnc;
        uint256 pendingAnc;
        // === 静态收益负债 ===
        uint256 debt;
    }

    struct StakingOrder{
        uint256 stakingUsdt;
        uint256 stakingLiquidity;
        uint256 stakingTime;
        bool    withdrawn;
    }

    //用户信息
    mapping(address => User) public userInfo;
    //用户质押订单存储
    mapping(address => StakingOrder[]) stakeOrdersBelongUser;
    //总质押的usdt，这个要用于计算anc奖励
    uint256 public totalStakeValidUsdt;
    //每个lp的质押收益
    uint256 public perStakeUsdtAwardAnc;
    //质押收益精度或者说全场收益精度
    uint256 decimals;

    //node奖励数据存储
    mapping(Process.NodeType => uint256) public cumulateAwardForNode;
    //2万usdt达标用户奖励数据存储
    uint256 public cumulateAwardForUsdtRank;
    //5万usdt达标用户的奖励数据存储，分发anc
    uint256 public cumulateAwardForAncRank;
    //英雄榜奖励数据存储
    uint256 public cumulateAwardForTodayTop;

    LiquidityManager public liquidityManager;
    FarmReferral public farmReferral;
    FarmNode public farmNode;
    FarmToday public farmToday;

    address admin;
    address community; //20%
    address buyBack; //30%
    address USDT;
    address ANC;

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(
        address _admin,
        address _community,
        address _buyBack,
        address _USDT,
        address _ANC,
        FarmReferral _farmReferral,
        FarmNode _farmNode,
        FarmToday _farmToday,
        LiquidityManager _liquidityManager
    ) public initializer {
        __Ownable_init(_msgSender());
        admin = _admin;
        community = _community;
        buyBack = _buyBack;
        USDT = _USDT;
        ANC = _ANC;
        
        //配套合约
        farmReferral = _farmReferral;
        farmNode = _farmNode;
        farmToday = _farmToday;
        liquidityManager = _liquidityManager;

        //精度设置
        decimals = 1e10;
    }

    function referral(address recommender) external{
        farmReferral.referral(recommender, msg.sender);
        emit Referrals(recommender, msg.sender);
    }
    
    function stake(uint256 amountUsdt) external{
        require(amountUsdt >= 100e18, "Invalid usdt amount.");
        User storage u = userInfo[msg.sender];
        (address recommender,,,,,) = farmReferral.referralInfo(msg.sender);
        require(recommender != address(0), "Must be have recommender.");
        require(u.nodeType == Process.NodeType.INVALID, "Staking is not permitted for nodes.");
        TransferHelper.safeTransferFrom(USDT, msg.sender, address(this), amountUsdt);
        
        uint256 toAddLiquidity = sendToken(amountUsdt);

        uint256 liquidity = liquidityManager.addLiquidity(msg.sender, toAddLiquidity);
        StakingOrder memory order = StakingOrder({
            stakingUsdt:toAddLiquidity,
            stakingLiquidity: liquidity,
            stakingTime: block.timestamp,
            withdrawn: false
        });
        stakeOrdersBelongUser[msg.sender].push(order);
        
        farmReferral.processStakeReferralInfo(msg.sender, toAddLiquidity, amountUsdt);
        farmToday.processTodayTopInfo(recommender, toAddLiquidity);

        u.pendingAnc += (u.stakingUsdt * perStakeUsdtAwardAnc - u.debt) / decimals;
        u.stakingUsdt += toAddLiquidity;
        u.debt = u.stakingUsdt * perStakeUsdtAwardAnc;
        totalStakeValidUsdt += toAddLiquidity;
    }

    function sendToken(
        uint256 amountUsdt
    ) internal returns(
        uint256 toAddLiquidity
    ){
        toAddLiquidity = amountUsdt * 66 / 100;
        uint256 toHierarchy = amountUsdt * 24 / 100;
        uint256 _remaining = amountUsdt - toAddLiquidity - toHierarchy;
        uint256 toUsdtRank = _remaining * 20 / 100;
        uint256 toNodeAddr = _remaining * 20 / 100;
        uint256 toTodayTop = _remaining * 10 / 100;
        uint256 toCommunity = _remaining * 20 / 100;
        uint256 toBuyBack = _remaining - (_remaining * 70 / 100);
        TransferHelper.safeTransfer(USDT, address(liquidityManager), toAddLiquidity);
        //2万usdt达标的数据存储在本合约，referral合约要更新层级收益
        cumulateAwardForUsdtRank += toUsdtRank;
        //不同节点奖励数据存储
        cumulateAwardForNode[Process.NodeType.SMALL] += toNodeAddr * 40 / 100;
        cumulateAwardForNode[Process.NodeType.MEDIUM] += toNodeAddr * 40 / 100;
        cumulateAwardForNode[Process.NodeType.LARGE] += (toNodeAddr - (toNodeAddr * 80 / 100));
        //英雄榜奖励数据存储
        cumulateAwardForTodayTop += toTodayTop;
        //打给指定地址的部分
        TransferHelper.safeTransfer(USDT, community, toCommunity);
        TransferHelper.safeTransfer(USDT, buyBack, toBuyBack);

    }

    function redeem(uint idx) external{
        User storage u = userInfo[msg.sender];
        StakingOrder storage order = stakeOrdersBelongUser[msg.sender][idx];
        require(!order.withdrawn, "Already redeem.");
        require(order.stakingLiquidity > 0, "Invalid liquidity.");
        u.stakingUsdt -= order.stakingUsdt;
        liquidityManager.redeemLiquidity(msg.sender, order.stakingTime, order.stakingLiquidity);
        order.withdrawn = true;
        //更新节点身份
        if(u.nodeType != Process.NodeType.INVALID) farmNode.removeToNodeAddr(u.nodeType, msg.sender);
        //更新业绩
        farmReferral.processRedeemReferralInfo(msg.sender, order.stakingUsdt);
    }

    function updateFarm(uint256 amount) external {
        require(msg.sender == ANC, "Not permit.");

        // 78% 分给所有质押用户
        uint256 totalForStakers = amount * 78 / 100;
        uint256 totalForAncRank = amount - totalForStakers; // 22%

        if (totalStakeValidUsdt > 0) {
            // 每个质押 1 USDT 的用户应获得的 ANC 奖励
            // 累加到 perStakeUsdtAwardAnc
            perStakeUsdtAwardAnc += totalForStakers * decimals / totalStakeValidUsdt;
        }

        // 22% 累加到 cumulateAwardForAncRank
        cumulateAwardForAncRank += totalForAncRank;
    }


    function getUserTruthAward(address user) public view returns(uint256 ancAward, uint256 usdtAward){
        // TODO 要考虑两者分发的精度问题，现在的处理方案是假设没有精度
        // (,uint256 usdtAward,uint256 ancAward,,,) = farmReferral.referralInfo(user);
        User memory u = userInfo[user];
        (,uint256 usdtReferralAward,uint256 ancReferralAward,,,) = farmReferral.referralInfo(user);
        uint256 usdtNodeAward = farmNode.usdtNodeAward(user);
        uint256 usdtTodayAward = farmToday.usdtTodayAward(user);
        usdtAward = (usdtReferralAward + usdtNodeAward + usdtTodayAward) - u.extractedUsdt;
        uint256 currentAwardAnc = (u.stakingUsdt * perStakeUsdtAwardAnc - u.debt) / decimals;
        ancAward = currentAwardAnc + u.pendingAnc + ancReferralAward - u.extractedAnc;
    }

    function claimAnc() external{
        
    }

    function claimUsdt() external{}

}