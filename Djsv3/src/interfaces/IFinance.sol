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


    function referral(address recommender, address user) external;
    function stake(address user, uint256 amountUSDT) external;
    function claim(address user) external;
    function swapSubToken(address user, uint256 amountUSDT) external;
    
}