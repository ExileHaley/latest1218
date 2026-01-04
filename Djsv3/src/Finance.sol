// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";
import {Errors} from "./libraries/Errors.sol";
import {Process} from "./libraries/Process.sol";
import {ILiquidityManager} from "./interfaces/ILiquidityManager.sol";

interface IDjsv1 {
    function userInfo(address user) 
        external 
        view 
        returns (
            address recommender, 
            uint256 staking, 
            uint256 performance, 
            uint256 referralNum
        );
    function getUserInfo(address user) 
        external 
        view 
        returns (
            address recommender, 
            uint256 staking, 
            uint256 performance, 
            uint256 referralNum, 
            address[] memory referrals
        );
}

interface INodeDividends {
    function updateFarm(uint256 amount) external;
}

contract Finance is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    event Referrals(address recommender,address referred);
    event Staked(address user, uint256 amount);
    event Claimed(address user, uint256 amount);

    // address public constant USDT = 0x3c83065B83A8Fd66587f330845F4603F7C49275c;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public   constant MULTIPLE = 3;
    uint256 constant SHARE_AWARD_RATE = 10;

    

    mapping(address => Process.User) public userInfo;
    mapping(address => Process.Referral) public referralInfo;
    mapping(address => Process.Record[]) awardRecords;
    mapping(address => address[]) directReferrals;
    mapping(address => bool) isAddDirectReferrals;
    mapping(Process.Level => uint256) public subCoinQuotas;

    address[] shareAddrs;
    mapping(address => bool) isAddShareAddrs;

    address USDT;
    address public admin;
    //首码、v1版本、节点、流动性处理地址
    address public initialCode;
    address public djsv1;
    address public nodeDividends;
    address public liquidityManager;
    address public recipientForBurn;
    //全局变量
    uint256 public totalStakedUsdt;
    //理财收益计算参数
    uint256 public perSecondStakedAeward;
    //精度
    uint256 decimals;

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    //暂停充值提现按钮
    bool    public pause;

    modifier Pause() {
        require(!pause, "Finance pause.");
        _;
    }

    modifier onlyAdmin(){
        require(admin == msg.sender, "Not permit.");
        _;
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(
        address _usdt,
        address _admin,
        address _initialCode,
        address _djsv1,
        address _nodeDividends,
        address _liquidityManager,
        address _recipientForBurn
    ) public initializer {
        __Ownable_init(_msgSender());
        USDT = _usdt;
        admin = _admin;
        initialCode = _initialCode;
        djsv1 = _djsv1;
        nodeDividends = _nodeDividends;
        liquidityManager = _liquidityManager;
        recipientForBurn = _recipientForBurn;
        decimals = 1e10;
        perSecondStakedAeward = uint256(12e18 * decimals / 1000e18 / 86400); //这里得计算一下每秒奖励的代币数
        subCoinQuotas[Process.Level.V1] = 100e18;
        subCoinQuotas[Process.Level.V2] = 300e18;
        subCoinQuotas[Process.Level.V3] = 500e18;
        subCoinQuotas[Process.Level.V4] = 1000e18;
        subCoinQuotas[Process.Level.V5] = 3000e18;
    }

    function setPause(bool isPause) external onlyAdmin{
        pause = isPause;
    }

    function setNodeDividends(address _nodeDividends) external onlyOwner{
        nodeDividends = _nodeDividends;
    }

    function setLiquidityManager(address _liquidityManager) external onlyOwner{
        liquidityManager = _liquidityManager;
    }

    function emergencyWithdraw(address _token, uint256 _amount, address _to) external onlyAdmin {
        TransferHelper.safeTransfer(_token, _to, _amount);
    }

    function migrationReferral(address user) external nonReentrant{
        Process.Referral storage r = referralInfo[user];
        if(r.isMigration) revert Errors.AlreadyMigrated();
        (address recommender,,,) = IDjsv1(djsv1).userInfo(user);
        if(recommender == address(0)) revert Errors.NoMigrationRequired();
        r.recommender = recommender;
        r.isMigration = true;
    }

    function referral(address recommender) external nonReentrant {
        //需要映射
        if(whetherNeedMigrate(msg.sender)) revert Errors.NeedMigrate();
        if(recommender == address(0)) revert Errors.ZeroAddress();
        if(recommender == msg.sender) revert Errors.InvalidRecommender();
        if(recommender != initialCode) {
            require(referralInfo[recommender].recommender != address(0) && userInfo[recommender].stakingUsdt > 0,"RECOMMENDATION_IS_REQUIRED_REFERRAL.");
        }
        if(referralInfo[msg.sender].recommender != address(0)) revert Errors.InviterExists();
        referralInfo[msg.sender].recommender = recommender;
        emit Referrals(recommender, msg.sender);
    }

    function swapSubToken(uint256 amountUSDT) external {
        if(amountUSDT > referralInfo[msg.sender].subCoinQuota) revert Errors.InsufficientQuota();
        TransferHelper.safeTransferFrom(USDT, msg.sender, liquidityManager, amountUSDT);
        ILiquidityManager(liquidityManager).swapForSubTokenToUser(msg.sender, amountUSDT);
        referralInfo[msg.sender].subCoinQuota -= amountUSDT;
    }

    function stake(uint256 amountUSDT) external nonReentrant{
        Process.User storage u = userInfo[msg.sender];
        Process.Referral storage r = referralInfo[msg.sender];
        if(r.recommender == address(0)) revert Errors.NotRequiredReferral();
        if(amountUSDT < 100e18) revert Errors.AmountTooLow();

        //分两次转账，给node(1%)/liquidity(99%)
        uint256 amountToNode = amountUSDT * 1 / 100;
        uint256 amountToBurnSubToken = amountUSDT * 1 / 100;
        uint256 amountToAddLiquidity = amountUSDT - amountToNode - amountToBurnSubToken;
        TransferHelper.safeTransferFrom(USDT, msg.sender, liquidityManager, amountToAddLiquidity);
        TransferHelper.safeTransferFrom(USDT, msg.sender, recipientForBurn, amountToBurnSubToken);
        TransferHelper.safeTransferFrom(USDT, msg.sender, nodeDividends, amountToNode);
        //处理node分红1%，子币销毁1%，添加流动性98%
        if(nodeDividends != address(0)) INodeDividends(nodeDividends).updateFarm(amountToNode);
        //剩余的98%用于添加流动性
        ILiquidityManager(liquidityManager).addLiquidity(amountToAddLiquidity);
        
        //更新用户质押收益、share等级收益
        _settleStakingReward(msg.sender);

        //质押数量更新
        u.stakingUsdt += amountUSDT;
        if(u.stakingUsdt >= 1000e18 && !u.addSubCoinQuota){
            u.addSubCoinQuota = true;
            r.subCoinQuota += 10e18;
        }
        //更新总质押totalStakedUsdt
        totalStakedUsdt += amountUSDT;

        if(!isAddDirectReferrals[msg.sender]){
            directReferrals[r.recommender].push(msg.sender);
            isAddDirectReferrals[msg.sender] = true;
        }

        processUpgrade(msg.sender, amountUSDT);
        emit Staked(msg.sender, amountUSDT);
    }

    function claim() external nonReentrant Pause {
        Process.User storage u = userInfo[msg.sender];
        if (u.stakingUsdt == 0) revert Errors.NoStake();

        // 1️⃣ 先计算本次 staking 收益（当前用户到现在的 staking 收益）
        uint256 stakingAward = getUserStakingAward(msg.sender);

        // 2️⃣ 结算 staking 收益 → 累加到 pendingProfit 并更新 stakingTime
        _settleStakingReward(msg.sender);

        // 3️⃣ 上级奖励按本次 staking 收益分发
        _processReferralAwards(msg.sender, stakingAward);

        // 4️⃣ 计算用户可提取总额（包括 pendingProfit）
        uint256 amount = getUserAward(msg.sender);
        if (amount == 0) revert Errors.NoReward();

        // 5️⃣ 更新用户状态
        u.pendingProfit = 0;        // 已计入 amount
        u.extracted += amount;      // 累加提取总额

        // 6️⃣ 发放 USDT
        ILiquidityManager(liquidityManager).acquireSpecifiedUsdt(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }



    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS/////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////

    function getUserStakingAward(address user) public view returns(uint256){
        Process.User memory u = userInfo[user];
        return (block.timestamp - u.stakingTime) * perSecondStakedAeward * u.stakingUsdt / decimals;
    }

    function getUserAward(address user) public view returns(uint256){
        Process.User memory u = userInfo[user];
        if (u.stakingUsdt == 0) return 0;
        // 1. 计算当前动态质押收益（还没结算进 pendingProfit 部分）
        // uint256 delta = block.timestamp - u.stakingTime;
        // uint256 stakeAward = u.stakingUsdt * delta * perSecondStakedAeward / decimals;
        uint256 stakeAward = getUserStakingAward(user);

        // 3. 用户当前总未提取收益
        uint256 totalAward = u.pendingProfit + stakeAward;

        //initialCode不受最大收益限制
        if(user == initialCode) return totalAward;
        // 4. 收益上限 = stakingUsdt * multiple
        uint256 maxAward = u.stakingUsdt * MULTIPLE;

        // 5. 用户剩余额度
        if (u.extracted >= maxAward) return 0;
        uint256 remaining = maxAward - u.extracted;

        // 6. 返回最小值
        if (totalAward > remaining) return remaining;
        return totalAward;
    }

    function whetherNeedMigrate(address user) public view returns(bool){
        (address v1Recommender,,,) = IDjsv1(djsv1).userInfo(user);
        // 需要迁移的条件：v1 有 recommender 且 新系统未标记为已迁移
        return (v1Recommender != address(0) && !referralInfo[user].isMigration);
    }

    /**
    * @dev 结算用户到当前时间为止的【质押收益】，
    *      只结算 staking 收益，不涉及 referral / share。
    *      调用后会重置 stakingTime。
    */
    function _settleStakingReward(address user) internal  {
        Process.User storage u = userInfo[user];

        // 没有质押则不处理
        if (u.stakingUsdt == 0) {
            u.stakingTime = block.timestamp;
            return;
        }

        // 距离上次结算的时间
        uint256 delta = block.timestamp - u.stakingTime;
        if (delta == 0) return;

        // 计算 staking 收益
        uint256 reward =
                delta
                * perSecondStakedAeward
                * u.stakingUsdt
                / decimals;

        // 累加到 pending
        if (reward > 0) {
            u.pendingProfit += reward;
        }

        // 重置质押时间
        u.stakingTime = block.timestamp;
    }

    function processUpgrade(address user, uint256 amount) internal{
        address current = referralInfo[user].recommender;

        while(current != address(0)){
            Process.Referral storage r = referralInfo[current];
            //人数放在邀请里吧
            r.referralNum += 1;
            r.performance += amount;

            uint256 directV5 = 0;
            if (r.level == Process.Level.V5) {
                address[] storage refs = directReferrals[current];
                uint256 len = refs.length;
                for (uint256 i = 0; i < len; ++i) {
                    if (referralInfo[refs[i]].level == Process.Level.V5) {
                        unchecked { ++directV5; }
                        if (directV5 >= 2) break;
                    }
                }
            }

            // 计算等级升级
            (Process.Level newLevel, bool upgrade) = Process.calcUpgradeLevel(r, directReferrals[current].length, directV5);
            
            if(upgrade) {
                r.level = newLevel;
                r.subCoinQuota += subCoinQuotas[newLevel];
                if(newLevel == Process.Level.SHARE && !isAddShareAddrs[current]) shareAddrs.push(current);
            }
            current = r.recommender;
        }

    }

    function getTotalSharePerformance() public view returns(uint256){
        uint256 total;
        if(shareAddrs.length == 0) return 0;
        for(uint i=0; i<shareAddrs.length; i++){
            total += referralInfo[shareAddrs[i]].performance;
        }
        return total;
    }

    function _settleShareAward(address user, uint256 stakingDelta) internal {
        uint256 len = shareAddrs.length;
        if (len == 0) return;

        uint256 totalPerf = getTotalSharePerformance();
        if (totalPerf == 0) return;

        // SHARE 只拿 10%
        uint256 sharePool = stakingDelta * SHARE_AWARD_RATE / 100;

        for (uint256 i = 0; i < len; ++i) {
            address s = shareAddrs[i];
            Process.Referral storage r = referralInfo[s];
            Process.User storage u = userInfo[s];

            // ⚠️ 关键：只按“当前 performance 占比”分本次 stakingDelta
            uint256 reward = sharePool * r.performance / totalPerf;
            if (reward == 0) continue;

            r.shareAward += reward;
            u.pendingProfit += reward;

            awardRecords[s].push(Process.Record({
                category:Process.Category.SHARE_LEVEL,
                from: user,
                amount: reward,
                time: block.timestamp
            }));  

        }
    }

    function _processLevelOnlyAward(address user, uint256 amount)
        internal
        returns (uint256 totalUsed)
    {
        bool[5] memory levelPaid;
        address current = referralInfo[user].recommender;

        while (current != address(0)) {
            Process.Referral storage r = referralInfo[current];
            Process.User storage u = userInfo[current];

            (uint256 reward, bool paid, uint8 idx) =
                Process.calcLevelReward(r.level, levelPaid, amount);

            if (paid) {
                levelPaid[idx] = true;
                u.pendingProfit += reward;
                r.referralAward += reward;
                totalUsed += reward;

                awardRecords[current].push(Process.Record({
                    category:Process.Category.NORMAL_LEVEL,
                    from: user,
                    amount: reward,
                    time: block.timestamp
                })); 

                if (totalUsed == amount * 50 / 100) break; // V1~V5 最多 50%
            }

            current = r.recommender;
        }
    }

    function _processDirectAward(address user, uint256 amount) internal{
        address direct = referralInfo[user].recommender;
        if (direct == address(0)) return;
        uint256 reward = amount * 10 / 100;
        Process.User storage u = userInfo[direct];
        Process.Referral storage r = referralInfo[direct];
        u.pendingProfit += reward;
        r.referralAward += reward;

        awardRecords[direct].push(Process.Record({
            category:Process.Category.DIRECT,
            from: user,
            amount: reward,
            time: block.timestamp
        }));       
    }

    function _processReferralAwards(address user, uint256 amount) internal {
        uint256 totalUsed = 0;

        // 1️⃣ 直推 10%
        _processDirectAward(user, amount);

        // 2️⃣ V1~V5 50%，同等级只给一次
        uint256 levelUsed = _processLevelOnlyAward(user, amount);
        totalUsed += levelUsed;

        // 3️⃣ V1~V5 未分完部分给 initialCode
        uint256 expectedLevelReward = amount * 50 / 100;
        if(levelUsed < expectedLevelReward){
            uint256 remaining = expectedLevelReward - levelUsed;
            Process.User storage u = userInfo[initialCode];
            Process.Referral storage r = referralInfo[initialCode];

            u.pendingProfit += remaining;
            r.referralAward += remaining;

            awardRecords[initialCode].push(Process.Record({
                category: Process.Category.NORMAL_LEVEL,
                from: user,
                amount: remaining,
                time: block.timestamp
            }));
        }

        // 4️⃣ SHARE 10%，调用已有逻辑
        _settleShareAward(user, amount);
    }

    function validReferralCode(address user) external view returns(bool){
        return userInfo[user].stakingUsdt > 0;
    }

    function getReferralAwardRecords(address user) external view returns(Process.Record[] memory){
        return awardRecords[user];
    }

    function getDirectReferralInfo(address user) external view returns(Process.Info[] memory){
        address[] storage refs = directReferrals[user];
        uint256 len = refs.length;
        Process.Info[] memory infos = new Process.Info[](len);

        for (uint256 i = 0; i < len; i++) {
            address u = refs[i];
            infos[i] = Process.Info({
                user: u,
                amount: userInfo[u].stakingUsdt + referralInfo[u].performance
            });
        }

        return infos;
    }

    function getShareAddrs() external view returns(address[] memory){
        return shareAddrs;
    }

    function getDirectReferralAddr(address user) external view returns(address[] memory){
        return directReferrals[user];
    }



    // // 返回用户基础信息 + 当前可提取收益 + Share等级收益
    // function getUserInfoBasic(address user) public view returns(
    //     uint256 stakingUsdt,
    //     uint256 extracted,
    //     uint256 remaining,
    //     uint256 stakingAward,
    //     uint256 extractable,
    //     uint256 referralAward,
    //     uint256 shareAward
    // ){
    //     Process.User memory u = userInfo[user];
    //     Process.Referral memory r = referralInfo[user];
    //     stakingUsdt = u.stakingUsdt;
    //     extracted = u.extracted;
    //     stakingAward = getUserStakingAward(user);
    //     //剩余待释放
    //     uint256 futureTotalAward = u.stakingUsdt * MULTIPLE;
    //     if(futureTotalAward >= u.extracted) remaining = futureTotalAward - u.extracted;
    //     else remaining = 0;
    //     // 当前可提取总收益
    //     extractable = getUserAward(user);
    //     // 当前Share等级收益
    //     referralAward = r.referralAward;
    //     shareAward = r.shareAward;
    // }

    // // 返回用户邀请/推荐相关信息
    // function getUserInfoReferral(address user) external view returns (
    //     Process.Level level,
    //     address recommender,
    //     uint256 referralNum,
    //     uint256 performance,
    //     uint256 subCoinQuota,
    //     bool    isMigration
    // ) {
    //     Process.Referral memory r = referralInfo[user];
    //     level = r.level;
    //     recommender = r.recommender;
    //     referralNum = r.referralNum;
    //     performance = r.performance;
    //     subCoinQuota = r.subCoinQuota;
    //     isMigration = r.isMigration;
    // }

}

