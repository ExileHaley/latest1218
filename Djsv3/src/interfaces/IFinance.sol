// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Process} from "../libraries/Process.sol";

interface IFinance{
    function initialCode() external view returns(address);
    function getUserStakingAward(address user) external view returns(uint256);
    function getUserAward(address user) external view returns(uint256);
    function getReferralAwardRecords(address user) external view returns(Process.Record[] memory);
    function getDirectReferralInfo(address user) external view returns(Process.Info[] memory);
    function getAmountOut(uint256 amountUSDT) external view returns(uint256);
    function totalStakedUsdt() external view returns(uint256);
    function validReferralCode(address user) external view returns(bool);
    function getDirectReferralAddr(address user) external view returns(address[] memory);
    function MULTIPLE() external view returns(uint256);
    function userInfo(address user) external view returns(
        uint256 stakingUsdt,
        uint256 stakingTime,
        uint256 pendingDividend,
        uint256 pendingBonus,
        uint256 extracted,
        bool    addSubCoinQuota
    );
    function referralInfo(address user) external view returns(
        address recommender,
        Process.Level   level,
        uint256 referralNum,
        uint256 performance,
        uint256 referralAward,
        uint256 shareAward,
        uint256 subCoinQuota,
        bool    isMigration,
        bool    underlingExistV5
    );

    function referral(address recommender, address user) external;
    function stake(address user, uint256 amountUSDT) external;
    function claim(address user) external;
    function swapSubToken(address user, uint256 amountUSDT) external;
    
}