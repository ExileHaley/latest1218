// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Process {
    enum Level {V0, V1, V2, V3, V4, V5, SHARE}
    enum Category {DIRECT, NORMAL_LEVEL, SHARE_LEVEL}

    struct User{
        uint256 stakingUsdt;        //质押数量
        uint256 stakingTime;        //质押时间
        uint256 pendingDividend;    //质押收益结余，计算使用
        uint256 pendingBonus;       //邀请奖励+share奖励，计算使用
        uint256 extracted;          //已提取收益   
        bool    addSubCoinQuota;    //大于1000u质押的用户有且只有给一次10U子币额度
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
        uint256 staking;
        uint256 performance;
    }

    // 计算某用户升级后的等级和新增 sharePerformance
    function calcUpgradeLevel(
        Process.Referral memory r,
        uint256 directReferralsCount,
        uint256 directV5Count
    ) internal pure returns (Level newLevel, bool upgrade) {

        // 默认保持原等级
        newLevel = r.level;
        upgrade = false;

        // 直接算最终应得等级（从高到低）
        if (directV5Count >= 2) {
            newLevel = Level.SHARE;
        }
        else if (directReferralsCount >= 9 && r.performance >= 3000000e18) {
            newLevel = Level.V5;
        }
        else if (directReferralsCount >= 7 && r.performance >= 800000e18) {
            newLevel = Level.V4;
        }
        else if (directReferralsCount >= 5 && r.performance >= 200000e18) {
            newLevel = Level.V3;
        }
        else if (directReferralsCount >= 4 && r.performance >= 50000e18) {
            newLevel = Level.V2;
        }
        else if (directReferralsCount >= 3 && r.performance >= 10000e18) {
            newLevel = Level.V1;
        }

        // 只要等级变高，就升级
        if (newLevel > r.level) {
            upgrade = true;
        }
    }


    function levelToIndex(Level lv) internal pure returns (bool valid, uint8 index) {
        if (lv == Level.V1) return (true, 0);
        if (lv == Level.V2) return (true, 1);
        if (lv == Level.V3) return (true, 2);
        if (lv == Level.V4) return (true, 3);
        if (lv == Level.V5) return (true, 4);
        return (false, 0);
    }

    function calcLevelBatchReward(
        Level lv,
        bool[5] memory levelPaid,
        uint256 amount
    )
        internal
        pure
        returns (
            uint256 reward,
            bool[5] memory newLevelPaid
        )
    {
        newLevelPaid = levelPaid;

        (bool valid, uint8 maxIndex) = levelToIndex(lv);
        if (!valid) return (0, newLevelPaid);

        for (uint8 i = 0; i <= maxIndex; i++) {
            if (newLevelPaid[i]) continue;

            reward += amount * 10 / 100;
            newLevelPaid[i] = true;
        }
    }



}