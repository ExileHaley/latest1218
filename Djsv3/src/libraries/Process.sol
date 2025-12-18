// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Process {
    enum Level {V0, V1, V2, V3, V4, V5, SHARE}

    struct User{
        uint256 stakingUsdt; //质押数量
        uint256 multiple;    //倍数
        uint256 stakingTime; //质押时间
        uint256 pendingProfit; //未提取收益
        uint256 extracted;     //已提取收益   
    }

    struct Referral{
        address recommender;    //推荐人地址
        Level   level;          //级别
        uint256 referralNum;    //有效邀请人数
        uint256 directV5Count;  //V5人数
        uint256 performance;    //邀请总业绩
        uint256 referralAward;  //邀请奖励
        uint256 subCoinQuota;   //子币额度
        uint256 shareAwardDebt; //share等级升级前的负债，避免多给
        bool    isMigration;    //是否映射旧版本邀请关系
    }

    struct Record{
        address from;   //奖励来源于谁的质押
        uint256 amount; //奖励数量
        uint256 time;   //获得奖励的时间
    }

    // 计算某用户升级后的等级和新增 sharePerformance
    function calcUpgradeLevel(
        Referral memory r,
        uint256 directReferralsCount,
        uint256 directV5Count
    ) internal pure returns (Level newLevel, uint256 addedShare, bool upgrade) {
        newLevel = r.level;
        addedShare = 0;
        upgrade = false;

        if(r.level == Level.V0 && directReferralsCount >= 3 && r.performance >= 10000e18){
            newLevel = Level.V1;
            upgrade = true;
        } else if(r.level == Level.V1 && directReferralsCount >= 4 && r.performance >= 50000e18){
            newLevel = Level.V2;
            upgrade = true;
        } else if(r.level == Level.V2 && directReferralsCount >= 5 && r.performance >= 200000e18){
            newLevel = Level.V3;
            upgrade = true;
        } else if(r.level == Level.V3 && directReferralsCount >= 7 && r.performance >= 800000e18){
            newLevel = Level.V4;
            upgrade = true;
        } else if(r.level == Level.V4 && directReferralsCount >= 9 && r.performance >= 3000000e18){
            newLevel = Level.V5;
            upgrade = true;
        } else if(r.level == Level.V5 && directV5Count >= 2){
            newLevel = Level.SHARE;
            addedShare = r.performance;
        }
    }

    // 计算某层级应该获得的奖励
    function calcReferralReward(Level lv, bool[6] memory hasRewarded, uint256 amount) 
        internal pure returns (uint256 reward, bool updated) 
    {
        reward = 0;
        updated = false;
        if(lv != Level.SHARE && lv != Level.V0){
            uint256 idx = uint256(lv);
            if(!hasRewarded[idx]){
                reward = amount * 10 / 100;
                updated = true;
            }
        }
    }

}