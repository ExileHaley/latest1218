// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Process {
    enum Level {V0, V1, V2, V3, V4, V5, SHARE}
    enum Category {DIRECT, NORMAL_LEVEL, SHARE_LEVEL}

    struct User{
        uint256 stakingUsdt; //质押数量
        uint256 stakingTime; //质押时间
        uint256 pendingProfit; //未提取收益
        uint256 extracted;     //已提取收益   
        bool    addSubCoinQuota; //大于1000u质押的用户有且只有给一次10U子币额度
    }

    struct Referral{
        address recommender;    //推荐人地址
        Level   level;          //级别
        uint256 referralNum;    //有效邀请人数
        uint256 performance;    //邀请总业绩
        uint256 referralAward;  //邀请奖励
        uint256 shareAward;     //share等级升级前的负债，避免多给
        uint256 subCoinQuota;   //子币额度
        bool    isMigration;    //是否映射旧版本邀请关系
    }

    struct Record{
        Category category; //奖励类别
        address from;   //奖励来源于谁的质押
        uint256 amount; //奖励数量
        uint256 time;   //获得奖励的时间
    }

    struct Info{
        address user;
        uint256 amount;
    }

    // 计算某用户升级后的等级和新增 sharePerformance
    function calcUpgradeLevel(
        Referral memory r,
        uint256 directReferralsCount,
        uint256 directV5Count
    ) internal pure returns (Level newLevel, bool upgrade) {
        newLevel = r.level;
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
            upgrade = true;
        }
    }

    function calcLevelReward(
        Level lv,
        bool[5] memory levelPaid,
        uint256 amount
    ) internal pure returns (uint256 reward, bool paid, uint8 levelIndex) {
        reward = 0;
        paid = false;
        levelIndex = 0;

        if (lv == Level.V1) levelIndex = 0;
        else if (lv == Level.V2) levelIndex = 1;
        else if (lv == Level.V3) levelIndex = 2;
        else if (lv == Level.V4) levelIndex = 3;
        else if (lv == Level.V5) levelIndex = 4;
        else return (0, false, 0);

        if (!levelPaid[levelIndex]) {
            reward = amount * 10 / 100;
            paid = true;
        }
    }



}