// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";
import { Process } from "./libraries/Process.sol";
import { FarmCore } from "./FarmCore.sol";


contract FarmReferral is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {

    
    using EnumerableSet for EnumerableSet.AddressSet;

    
    uint16[20] public levelPercents;

    struct Referral {
        address recommender;
        uint256 usdtReferralAward;
        uint256 ancReferralAward;
        uint256 overallPerformance;
        uint256 effectivePerformance;
        uint256 referralNum;
    }


    mapping(address => Referral) public referralInfo;
    mapping(address => Process.Record[]) public awardRecords;
    mapping(address => EnumerableSet.AddressSet)  directReferralAddrSets;
    EnumerableSet.AddressSet private usdtRankAddrSets;
    EnumerableSet.AddressSet private ancRankAddrSets;
    mapping(address => mapping(address => uint256)) public linePerformance;
    mapping(address => address) public maxChild;
    uint256 public totalUsdtRankEffectivePerformance;
    uint256 public totalAncRankEffectivePerformance;

    FarmCore farmCore;
    address initialCode;

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner() {}

    function initialize(address _initialCode) public initializer {
        __Ownable_init(_msgSender());
        initialCode = _initialCode;
        levelPercents = [
            1000,500,200,80,80,80,80,80,80,20,
            20,20,20,20,20,20,20,20,20,20
        ];

    }

    modifier onlyCore() {
        require(address(farmCore) == msg.sender, "Not permit.");
        _;
    } 

    function setFarmCore(FarmCore _farmCore) external onlyOwner {
        farmCore = _farmCore;
    }  

    function getRecommender(address user) external view returns(address) {
        return referralInfo[user].recommender;
    }

    function referral(address recommender, address user) external nonReentrant onlyCore{
        require(user != initialCode, "Invalid sender");
        if(recommender == address(0)) recommender = initialCode;
        require(recommender != user, "Invalid recommender");

        (,uint256 stakingUsdt,,,,) = farmCore.userInfo(recommender);
        if(recommender != initialCode) {
            require(referralInfo[recommender].recommender != address(0) && stakingUsdt > 0,"RECOMMENDATION_IS_REQUIRED_REFERRAL.");
        }
        require(referralInfo[user].recommender == address(0), "InviterExists.");
        referralInfo[user].recommender = recommender;
        
    }
    
    function processStakeReferralInfo(address user,uint256 amountLiquidity,uint256 amountUsdt) external onlyCore {
        
        uint8 level = 1;
        uint256 num = 0;

        if(!directReferralAddrSets[referralInfo[user].recommender].contains(user)) {
            directReferralAddrSets[referralInfo[user].recommender].add(user);
            num = 1;
        }

        address current = referralInfo[user].recommender;
        while(current != address(0) && level <= 20) {
            Referral storage r = referralInfo[current];
            r.referralNum += num;
            r.overallPerformance += amountLiquidity;
            linePerformance[current][user] += amountLiquidity;

            // 更新大区
            address oldMax = maxChild[current];
            if(oldMax == address(0) || linePerformance[current][user] > linePerformance[current][oldMax] || 
               (linePerformance[current][user] == linePerformance[current][oldMax] && user < oldMax)) {
                maxChild[current] = user;
            }

            _updateEffectiveAndRank(current);
            //层级奖励
            uint256 directCount = directReferralAddrSets[current].length();
            uint8 maxLevelForThisRecommender = directCount > 9 ? 20 : uint8(directCount);

            if(level <= maxLevelForThisRecommender && amountUsdt > 0) {
                uint256 reward = amountUsdt * levelPercents[level - 1] / 10000;
                if(reward > 0) {
                    r.usdtReferralAward += reward;
                    awardRecords[current].push(Process.Record({
                        token: Process.Token.USDT_TOKEN,
                        from: user,
                        amount: reward,
                        time: block.timestamp
                    }));
                }
            }


            current = r.recommender;
            level++;
        }
    }

    function processRedeemReferralInfo(address user,uint256 stakingUsdt) external onlyCore {
        address current = referralInfo[user].recommender;
        uint8 level = 1;

        while(current != address(0) && level <= 20) {
            Referral storage r = referralInfo[current];

            r.overallPerformance = r.overallPerformance >= stakingUsdt ? r.overallPerformance - stakingUsdt : 0;
            linePerformance[current][user] = linePerformance[current][user] >= stakingUsdt ? linePerformance[current][user] - stakingUsdt : 0;

            // 重算大区
            address oldMax = maxChild[current];
            if(oldMax == user || oldMax == address(0)) {
                address[] memory directs = directReferralAddrSets[current].values();
                address newMax;
                uint256 maxValue;
                for(uint256 i=0;i<directs.length;i++){
                    address child = directs[i];
                    uint256 v = linePerformance[current][child];
                    if(v > maxValue || (v == maxValue && (newMax == address(0) || child < newMax))) {
                        maxValue = v;
                        newMax = child;
                    }
                }
                maxChild[current] = newMax;
            }

            _updateEffectiveAndRank(current);

            current = r.recommender;
            level++;
        }
    }

    // ===== 内部函数：更新小区业绩和榜单 =====
    function _updateEffectiveAndRank(address user) internal {
        Referral storage r = referralInfo[user];
        uint256 oldEffective = r.effectivePerformance;

        // 找到所有直推的总业绩，记录最大值
        address[] memory directs = directReferralAddrSets[user].values();
        uint256 totalDirectPerformance = 0;
        uint256 maxDirectPerformance = 0;
        address maxDirectAddr;
        for(uint256 i = 0; i < directs.length; i++){
            uint256 p = linePerformance[user][directs[i]];
            totalDirectPerformance += p;
            if(p > maxDirectPerformance || (p == maxDirectPerformance && directs[i] < maxDirectAddr)){
                maxDirectPerformance = p;
                maxDirectAddr = directs[i];
            }
        }
        maxChild[user] = maxDirectAddr;

        uint256 newEffective = totalDirectPerformance - maxDirectPerformance;
        r.effectivePerformance = newEffective;

        // 更新榜单
        if(usdtRankAddrSets.contains(user)) {
            totalUsdtRankEffectivePerformance = totalUsdtRankEffectivePerformance + newEffective - oldEffective;
        }

        if(ancRankAddrSets.contains(user)) {
            totalAncRankEffectivePerformance = totalAncRankEffectivePerformance + newEffective - oldEffective;
        }

        if(newEffective >= 2e4 * 1e18) usdtRankAddrSets.add(user);
        if(newEffective >= 5e4 * 1e18) ancRankAddrSets.add(user);
        if(newEffective < 2e4 * 1e18) usdtRankAddrSets.remove(user);
        if(newEffective < 5e4 * 1e18) ancRankAddrSets.remove(user);
    }


    function issueUsdtAwardForRank(uint256 amount) external onlyCore {
        if(totalUsdtRankEffectivePerformance == 0 || amount == 0) return;
        address[] memory rankUsers = usdtRankAddrSets.values();
        for(uint256 i=0;i<rankUsers.length;i++){
            address u = rankUsers[i];
            Referral storage r = referralInfo[u];
            if(r.effectivePerformance == 0) continue;
            uint256 reward = amount * r.effectivePerformance / totalUsdtRankEffectivePerformance;
            if(reward == 0) continue;
            r.usdtReferralAward += reward;
            awardRecords[u].push(Process.Record({token: Process.Token.USDT_TOKEN, from: address(0), amount: reward, time: block.timestamp}));
        }
    }

    function issueAncAwardForRank(uint256 amount) external onlyCore {
        if (totalAncRankEffectivePerformance == 0 || amount == 0) return; // 避免除以0

        address[] memory rankUsers = ancRankAddrSets.values();

        for (uint256 i = 0; i < rankUsers.length; i++) {
            address user = rankUsers[i];
            Referral storage r = referralInfo[user];

            if (r.effectivePerformance < 5e4 * 1e18) continue; // 安全防护：只对达标用户发放

            // 计算奖励
            uint256 reward = amount * r.effectivePerformance / totalAncRankEffectivePerformance;
            if (reward == 0) continue;

            // 累加到ancAward
            r.ancReferralAward += reward;

            // 记录奖励
            awardRecords[user].push(Process.Record({
                token: Process.Token.ANC_TOKEN,
                from: address(0), // 全局榜单奖励，没有单个来源
                amount: reward,
                time: block.timestamp
            }));
        }
    }

    

    function getDirectReferralAddrs(address user) public view returns(address[] memory){
        return directReferralAddrSets[user].values();
    }

    function getUsdtRankAddrs() public view returns(address[] memory){
        return usdtRankAddrSets.values();
    }

    function getAncRankAddrs() public view returns(address[] memory){
        return ancRankAddrSets.values();
    }
}
