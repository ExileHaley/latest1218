// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Process {
    enum Level {V0, V1, V2, V3, V4, V5, SHARE}
    enum Category {DIRECT, NORMAL_LEVEL, SHARE_LEVEL}

    struct User{
        uint256 stakingUsdt;  
        uint256 stakingTime;      
        uint256 pendingDividend;    
        uint256 pendingBonus;       
        uint256 extracted;        
        bool    addSubCoinQuota;   
    }

    struct Referral{
        address recommender;  
        Level   level;        
        uint256 referralNum;   
        uint256 performance;   
        uint256 referralAward;  
        uint256 shareAward;     
        uint256 subCoinQuota;   
        bool    isMigration;   
        bool    underlingExistV5;       
    }

    struct Record{
        Category category; 
        address from;  
        uint256 amount; 
        uint256 time;   
    }

    struct Info{
        address user;
        uint256 staking;
        uint256 performance;
    }


    function calcUpgradeLevel(
        Process.Referral memory r,
        uint256 directReferralsCount,
        uint256 directV5Count
    ) internal pure returns (Level newLevel, bool upgrade) {


        newLevel = r.level;
        upgrade = false;


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