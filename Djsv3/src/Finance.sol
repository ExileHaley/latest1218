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
import {ILiquidity} from "./interfaces/ILiquidity.sol";

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

    // IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant USDT = 0x3c83065B83A8Fd66587f330845F4603F7C49275c;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    //个人数据存储
    mapping(address => Process.User) public userInfo;
    mapping(address => Process.Referral) public referralInfo;
    mapping(address => Process.Record[]) public awardRecords;
    mapping(address => address[]) public directReferrals;
    mapping(address => bool) public isAddDirectReferrals;
    mapping(Process.Level => uint256) public subCoinQuotas;

    //管理员
    address public admin;
    //首码、v1版本、节点、流动性处理地址
    address public initialCode;
    address public djsv1;
    address public nodeDividends;
    address public liquidityManager;
    //全局变量
    uint256 public totalStakedUsdt;
    //暂停充值提现按钮
    bool    public pause;
    //理财收益计算参数
    uint256 public perSecondStakedAeward;
    //精度
    uint256   public decimals;
    //share等级收益计算变量
    uint256 public lastShareAwardTime;
    uint256 public perSharePerformanceAward;
    uint256 public totalSharePerformance;
    uint256 public shareRate;

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

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
        address _admin,
        address _initialCode,
        address _djsv1,
        address _nodeDividends,
        address _liquidityManager
    ) public initializer {
        __Ownable_init(_msgSender());
        admin = _admin;
        initialCode = _initialCode;
        djsv1 = _djsv1;
        nodeDividends = _nodeDividends;
        liquidityManager = _liquidityManager;
        decimals = 1e10;
        perSecondStakedAeward = uint256(12e18 * decimals / 1000e18 / 86400); //这里得计算一下每秒奖励的代币数
        shareRate = 10; //share 奖励比例10%
        lastShareAwardTime = block.timestamp;
        subCoinQuotas[Process.Level.V1] = 100e18;
        subCoinQuotas[Process.Level.V2] = 300e18;
        subCoinQuotas[Process.Level.V3] = 500e18;
        subCoinQuotas[Process.Level.V4] = 1000e18;
        subCoinQuotas[Process.Level.V5] = 3000e18;
    }

    function setPause(bool isPause) external onlyAdmin{
        pause = isPause;
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
        ILiquidity(liquidityManager).swapForSubTokenToUser(msg.sender, amountUSDT);
        referralInfo[msg.sender].subCoinQuota -= amountUSDT;
    }

    function stake(uint256 amountUSDT) external nonReentrant{
        Process.User storage u = userInfo[msg.sender];
        Process.Referral storage r = referralInfo[msg.sender];
        if(r.recommender == address(0)) revert Errors.NotRequiredReferral();
        if(amountUSDT < 100e18) revert Errors.AmountTooLow();

        //分两次转账，给node(1%)/liquidity(99%)
        uint256 amountUSDTToNode = amountUSDT * 1 / 100;
        uint256 amountToBurnSubToken = amountUSDT * 1 / 100;
        TransferHelper.safeTransferFrom(USDT, msg.sender, liquidityManager, amountUSDT - amountUSDTToNode);
        TransferHelper.safeTransferFrom(USDT, msg.sender, nodeDividends, amountUSDTToNode);
        //处理node分红1%，子币销毁1%，添加流动性98%
        ILiquidity(liquidityManager).swapForSubTokenToBurn(amountToBurnSubToken);
        if(nodeDividends != address(0)) INodeDividends(nodeDividends).updateFarm(amountUSDTToNode);
        //剩余的98%用于添加流动性
        ILiquidity(liquidityManager).addLiquidity(amountUSDT - amountUSDTToNode - amountToBurnSubToken);
        
        //更新用户质押收益、share等级收益
        _settleStakingReward(msg.sender);
        updateShareFram(totalStakedUsdt);
        if(r.level == Process.Level.SHARE) _settleShareReward(msg.sender);

        //根据数量设置倍数 multiple
        u.stakingUsdt += amountUSDT;
        uint256 newMultiple = u.stakingUsdt > 3000e18 ? 3 : 2;
        if (u.multiple != newMultiple) {
            u.multiple = newMultiple;
        }
        //更新总质押totalStakedUsdt
        totalStakedUsdt += amountUSDT;

        if(!isAddDirectReferrals[msg.sender]){
            directReferrals[r.recommender].push(msg.sender);
            isAddDirectReferrals[msg.sender] = true;
        }

        // uint256 sharePerformance = processLayer(msg.sender, amountUSDT);
        processUpgrade(msg.sender, amountUSDT);
        emit Staked(msg.sender, amountUSDT);
    }

    function claim() external nonReentrant Pause{
        Process.User storage u = userInfo[msg.sender];
        if (u.stakingUsdt == 0) revert Errors.NoStake();

        uint256 validStaked = totalStakedUsdt - getInvalidStaking(msg.sender);
        updateShareFram(validStaked);

        uint256 amount = getUserAward(msg.sender);
        if (amount == 0) revert Errors.NoReward();

        u.pendingProfit = 0;
        u.extracted += amount;
        Process.Referral storage r = referralInfo[msg.sender];
        r.referralAward = 0;
        if (r.level == Process.Level.SHARE) {
            r.shareAwardDebt = perSharePerformanceAward * r.performance;
        }

        ILiquidity(liquidityManager).acquireSpecifiedUsdt(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }


    function getUserAward(address user) public view returns(uint256){
        Process.User memory u = userInfo[user];
        if (u.stakingUsdt == 0) return 0;

        // 1. 计算当前动态质押收益（还没结算进 pendingProfit 部分）
        // uint256 delta = block.timestamp - u.stakingTime;
        // uint256 stakeAward = u.stakingUsdt * delta * perSecondStakedAeward / decimals;
        uint256 stakeAward = getUserStakingAward(user);

        // 2. SHARE 等级收益（此部分可动态计算，不累加进 pendingProfit）
        uint256 shareAward = getUserShareLevelAward(user);

        // 3. 用户当前总未提取收益
        uint256 totalAward = u.pendingProfit + stakeAward + shareAward + referralInfo[user].referralAward;

        //initialCode不受最大收益限制
        if(user == initialCode) return totalAward;
        // 4. 收益上限 = stakingUsdt * multiple
        uint256 maxAward = u.stakingUsdt * u.multiple;

        // 5. 用户剩余额度
        if (u.extracted >= maxAward) return 0;
        uint256 remaining = maxAward - u.extracted;

        // 6. 返回最小值
        if (totalAward > remaining) return remaining;
        return totalAward;
    }

    //计算Share等级的收益
    //1.每次claim时更新perSharePerformanceAward，用totalStakedUsdt * 时间间隔 * 每个质押收益 / 总的share等级业绩
    //2.计算动态收益，按照上述方式计算没更新的当前时间段内的收益，动态计算不依赖更新
    //3.把两部分的收益加起来就等于总的Share等级收益
    function getUserShareLevelAward(address user) public view returns(uint256){
        if(lastShareAwardTime ==0 ) return 0;
        Process.Referral memory r = referralInfo[user];
        if (r.performance == 0 || totalSharePerformance == 0) return 0;

        // 累计奖励
        uint256 acc = perSharePerformanceAward;

        // 动态奖励（未更新到 perSharePerformanceAward 的部分）
        uint256 delta = block.timestamp - lastShareAwardTime;
        if (delta > 0) {
            uint256 totalShareAward = totalStakedUsdt * delta * perSecondStakedAeward * shareRate / 100;
            acc += totalShareAward / totalSharePerformance;
        }

        uint256 reward = r.performance * acc / decimals;

        // 扣除用户已结算债务
        if (reward <= r.shareAwardDebt) return 0;
        return reward - r.shareAwardDebt;
    }

    function getUserStakingAward(address user) public view returns(uint256){
        Process.User memory u = userInfo[user];
        return (block.timestamp - u.stakingTime) * perSecondStakedAeward * u.stakingUsdt / decimals;
    }


    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS UTILS/////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////

    /**
    * @dev 结算用户到当前时间为止的【股东分红收益】，
    *      只结算 share 收益，不涉及 referral / staking
    *      调用后会更新用户的share等级负债，避免前期收益重复累加
    */

    function _settleShareReward(address user) internal{
        
        uint256 shareAward = getUserShareLevelAward(msg.sender);
        if(shareAward > 0) {
            userInfo[user].pendingProfit += shareAward;
            referralInfo[user].shareAwardDebt = perSharePerformanceAward * referralInfo[user].performance;
        }
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
    /**
    * @dev 更新SHARE等级每份业绩的收益
    *      totalStaked用户claim时候更新数据，totalStaked在claim中需要计算有效的部分
    *      更新最新的lastShareAwardTime
    */
    function updateShareFram(uint256 totalStaked) internal {

        uint256 delta = block.timestamp - lastShareAwardTime;
        if (delta == 0 || totalSharePerformance == 0) {
            lastShareAwardTime = block.timestamp;
            return;
        }

        uint256 totalShareAward =
            totalStaked * delta * perSecondStakedAeward * shareRate / 100;

        perSharePerformanceAward += totalShareAward / totalSharePerformance;
        lastShareAwardTime = block.timestamp;
    }
    

    /**
    * @dev 计算用户升级并更新数据
    *      更新的数据包括邀请业绩、分法奖励、存储奖励记录，添加子币额度
    *      如果用户刚升级SHARE还需要加上总的SHARE业绩
    */
    function processUpgrade(address user, uint256 amount) internal{
        address current = referralInfo[user].recommender;
        bool[6] memory hasRewarded;
        uint256 totalRate = 50;
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

            
            // 发放奖励
            (uint256 reward, bool updated) = Process.calcReferralReward(r.level, hasRewarded, amount);
            if(updated){
                r.referralAward += reward;
                awardRecords[current].push(Process.Record(user, reward, block.timestamp));
                hasRewarded[uint256(r.level)] = true;
                totalRate -= 10;
            }

            // 计算等级升级
            (Process.Level newLevel, uint256 addedShare, bool upgrade) = Process.calcUpgradeLevel(r, directReferrals[current].length, directV5);
            
            if(upgrade) {
                r.level = newLevel;
                totalSharePerformance += addedShare;
                r.subCoinQuota += subCoinQuotas[newLevel];
            }
            // 累加人数和业绩
            current = r.recommender;
        }

        // 剩余奖励给 initialCode
        if(totalRate > 0){
            referralInfo[initialCode].referralAward += (amount * totalRate)/100;
        }
    }

    function getReferralAwardRecords(address user) external view returns(Process.Record[] memory){
        return awardRecords[user];
    }

    function getDirectReferrals(address user) external view returns(address[] memory){
        return directReferrals[user];
    }

    function whetherNeedMigrate(address user) public view returns(bool){
        (address v1Recommender,,,) = IDjsv1(djsv1).userInfo(user);
        // 需要迁移的条件：v1 有 recommender 且 新系统未标记为已迁移
        return (v1Recommender != address(0) && !referralInfo[user].isMigration);
    }

    function validReferralCode(address user) external view returns(bool){
        return userInfo[user].stakingUsdt > 0;
    }

    function getInvalidStaking(address user) public view returns(uint256){
        Process.User storage u = userInfo[user];
        uint256 totalAward = u.pendingProfit + getUserStakingAward(user) + getUserShareLevelAward(user) / decimals + u.extracted;
        if (totalAward > u.stakingUsdt * u.multiple) return u.stakingUsdt;
        else return 0; 

    }

    // 返回用户基础信息 + 当前可提取收益 + Share等级收益
    function getUserInfoBasic(address user) public view returns(
        Process.Level level,
        address recommender,
        uint256 stakingUsdt,
        uint256 multiple,
        uint256 totalAward,
        uint256 shareAward
    ){
        Process.User memory u = userInfo[user];
        Process.Referral memory r = referralInfo[user];

        level = r.level;
        recommender = r.recommender;
        stakingUsdt = u.stakingUsdt;
        multiple = u.multiple;

        // 当前可提取总收益
        totalAward = getUserAward(user);
        // 当前Share等级收益
        shareAward = getUserShareLevelAward(user);
    }

    // 返回用户邀请/推荐相关信息
    function getUserInfoReferral(address user) external view returns (
        uint256 referralNum,
        uint256 performance,
        uint256 referralAward,
        uint256 subCoinQuota,
        bool    isMigration
    ) {
        Process.Referral memory r = referralInfo[user];

        referralNum = r.referralNum;
        performance = r.performance;
        referralAward = r.referralAward;
        subCoinQuota = r.subCoinQuota;
        isMigration = r.isMigration;
    }

}
