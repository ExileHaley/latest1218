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



interface IAnc{
    function burnFromPair() external returns(uint256); 
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
    // uint256 public cumulateAwardForAncRank;
    //英雄榜奖励数据存储
    uint256 public cumulateAwardForTodayTop;

    LiquidityManager  liquidityManager;
    FarmReferral  farmReferral;
    FarmNode  farmNode;
    FarmToday  farmToday;

    address admin;
    address community; //20%
    address buyBack; //30%
    address USDT;
    address ANC;

    modifier onlyAdmin() {
        require(admin == msg.sender, "Not permit.");
        _;
    }

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

    // 添加节点函数


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

        u.pendingAnc += u.stakingUsdt * perStakeUsdtAwardAnc - u.debt;
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

    function redeem(uint256 idx) external {
        User storage u = userInfo[msg.sender];
        StakingOrder storage order = stakeOrdersBelongUser[msg.sender][idx];

        require(!order.withdrawn, "Already redeem.");
        require(order.stakingLiquidity > 0, "Invalid liquidity.");

        // ===== ① 先结算 ANC（关键）=====
        uint256 pendingFromStake =
            (u.stakingUsdt * perStakeUsdtAwardAnc - u.debt) / decimals;

        if (pendingFromStake > 0) {
            u.pendingAnc += pendingFromStake;
        }

        // ===== ② 再减少 stakingUsdt =====
        u.stakingUsdt -= order.stakingUsdt;

        // ===== ③ 同步 debt 到新 stakingUsdt =====
        u.debt = u.stakingUsdt * perStakeUsdtAwardAnc;

        // 更新全局质押数量
        totalStakeValidUsdt -= order.stakingUsdt;
        // ===== ④ 外部逻辑 =====
        liquidityManager.redeemLiquidity(
            msg.sender,
            order.stakingTime,
            order.stakingLiquidity
        );

        order.withdrawn = true;

        if (u.nodeType != Process.NodeType.INVALID) {
            farmNode.removeToNodeAddr(u.nodeType, msg.sender);
        }

        farmReferral.processRedeemReferralInfo(
            msg.sender,
            order.stakingUsdt
        );
    }


    function updateFarmUsdt(uint256 amount) external {
        require(msg.sender == ANC, "Not permit.");
        uint256 forNode = amount * 40 / 100;
        uint256 forSmall = forNode * 40 / 100;
        uint256 forLarge = forNode - (forNode * 80 / 100);
        cumulateAwardForNode[Process.NodeType.SMALL] += forSmall;
        cumulateAwardForNode[Process.NodeType.MEDIUM] += forSmall;
        cumulateAwardForNode[Process.NodeType.LARGE] += forLarge;

        uint256 forUsdtRank = amount * 40 / 100;
        cumulateAwardForUsdtRank += forUsdtRank;

        uint256 forTodayTop = amount - forNode - forUsdtRank;
        cumulateAwardForTodayTop += forTodayTop;

    }

    function updateFarmAnc(uint256 amount) internal {
        uint256 totalForStakers = amount;

        if (totalStakeValidUsdt > 0) {
            perStakeUsdtAwardAnc += totalForStakers * decimals / totalStakeValidUsdt;
        }
    }

    //getUserTruthAward + claimUsdt + claimAnc这三个逻辑不连贯
    function getUserTruthAward(address user)
        public
        view
        returns (uint256 ancAward, uint256 usdtAward)
    {
        User memory u = userInfo[user];

        // ===== USDT（你现在是 OK 的）=====
        (, uint256 usdtReferralAward, uint256 ancReferralAward,,,) =
            farmReferral.referralInfo(user);

        uint256 usdtNodeAward = farmNode.usdtNodeAward(user);
        uint256 usdtTodayAward = farmToday.usdtTodayAward(user);

        uint256 totalUsdt =
            usdtReferralAward + usdtNodeAward + usdtTodayAward;

        usdtAward = totalUsdt - u.extractedUsdt;

        // ===== ANC（关键修正）=====
        uint256 pendingFromStake =
            (u.stakingUsdt * perStakeUsdtAwardAnc - u.debt) / decimals;

        ancAward =
            u.pendingAnc
            + pendingFromStake
            + ancReferralAward
            - u.extractedAnc;
    }


    function claimUsdt() external nonReentrant {
        (, uint256 usdtAward) = getUserTruthAward(msg.sender);
        require(usdtAward > 0, "No USDT reward");

        userInfo[msg.sender].extractedUsdt += usdtAward;
        TransferHelper.safeTransfer(USDT, msg.sender, usdtAward);
    }

    function claimAnc() external nonReentrant {
        (uint256 ancAward, ) = getUserTruthAward(msg.sender);
        require(ancAward > 0, "No ANC reward");

        User storage u = userInfo[msg.sender];
        (,, uint256 ancReferralAward,,,) = farmReferral.referralInfo(msg.sender);
        u.extractedAnc += ancReferralAward;

        u.pendingAnc = 0;
        u.debt = u.stakingUsdt * perStakeUsdtAwardAnc;

        TransferHelper.safeTransfer(ANC, msg.sender, ancAward);
    }

    function issueUsdtRankAward() public {
        farmReferral.issueUsdtAwardForRank(cumulateAwardForUsdtRank);
        cumulateAwardForUsdtRank = 0;
    }
    

    function issueAncRankAward() public {
        uint256 amountAnc = IAnc(ANC).burnFromPair();
        uint256 toStaking = amountAnc * 78 / 100;
        updateFarmAnc(toStaking);
        farmReferral.issueAncAwardForRank(amountAnc - toStaking);
    }

    function issueTodayTopUsdtAward() public {
        farmToday.issueTodayTopAward(cumulateAwardForTodayTop);
        cumulateAwardForTodayTop = 0;
    }

    function issueSmallNodeAward() public {
        Process.NodeType[] memory nodeTypes = new Process.NodeType[](1);
        nodeTypes[0] = Process.NodeType.SMALL;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = cumulateAwardForNode[Process.NodeType.SMALL];

        farmNode.issueNodeAward(nodeTypes, amounts);
    }

    function issueOtherNodeAward() public {
        Process.NodeType[] memory nodeTypes = new Process.NodeType[](2);
        nodeTypes[0] = Process.NodeType.MEDIUM;
        nodeTypes[1] = Process.NodeType.LARGE;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = cumulateAwardForNode[Process.NodeType.MEDIUM];
        amounts[1] = cumulateAwardForNode[Process.NodeType.LARGE];

        farmNode.issueNodeAward(nodeTypes, amounts);
    }

    function getAwardRecord(address user) external view returns(
        Process.Record[] memory node,
        Process.Record[] memory today,
        Process.Record[] memory invite
    ){
        node = farmNode.getAwardRecords(user);
        today = farmNode.getAwardRecords(user);
        invite = farmReferral.getAwardRecords(user);
    }

    // 获取直推地址信息
    function getDirectReferralAddrInfo(address user) external view returns(Process.Info[] memory infos) {
        address[] memory directs = farmReferral.getDirectReferralAddrs(user);
        infos = new Process.Info[](directs.length);

        for (uint i = 0; i < directs.length; i++) {
            address directAddr = directs[i];

            // 从 FarmCore 获取 stakingUsdt
            User memory u = userInfo[directAddr];

            // 从 FarmReferral 获取 overall 和 effective
            (, , , uint256 overallPerformance, uint256 effectivePerformance, ) = farmReferral.referralInfo(directAddr);

            infos[i] = Process.Info({
                user: directAddr,
                stakingUsdt: u.stakingUsdt,
                overall: overallPerformance,
                effective: effectivePerformance
            });
        }
    }


    function getUserInfo(address user) external view returns(
        Process.NodeType nodeType,
        uint256 stakingUsdt,
        StakingOrder[] memory orders,
        address recommender,
        uint256 overallPerformance,
        uint256 effectivePerformance,
        uint256 referralNum,
        uint256 ancAward,
        uint256 usdtAward,
        bool isRankAnc, 
        bool isRankUsdt
    ){
        (
            recommender,,,
            overallPerformance,
            effectivePerformance,
            referralNum
        ) = farmReferral.referralInfo(user);

        User memory u = userInfo[user];
        nodeType = u.nodeType;
        stakingUsdt = u.stakingUsdt;
        orders = stakeOrdersBelongUser[user];

        (ancAward, usdtAward) = getUserTruthAward(user);
        (isRankAnc, isRankUsdt) = farmReferral.getBelongToRank(user);
    }
    
    function getTodayTopInfo() external view returns(Process.Today[] memory){
        return farmToday.getTodayTopInfo();
    }

    function getInitialCode() external view returns(address){
        return farmReferral.initialCode();
    }

    function eligibilityCode(address user) external view returns(bool){
        return userInfo[user].stakingUsdt > 0;
    }

}