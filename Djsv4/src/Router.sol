// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFinance} from "./interfaces/IFinance.sol";
import {Process} from "./libraries/Process.sol";
contract Router is Ownable{

    address public finance;
    
    address public liquidityManager;

    constructor(address _finance, address _liquidityManager)Ownable(msg.sender){
        finance = _finance;
        liquidityManager = _liquidityManager;
    }

    function initialCode() external view returns(address){
        return 
            IFinance(finance).initialCode();
    }

    function getUserStakingAward(address user) external view returns(uint256){
        return 
            IFinance(finance).getUserStakingAward(user);
    }

    function getUserAward(address user) external view returns(uint256){
        return 
            IFinance(finance).getUserAward(user);
    }

    function getReferralAwardRecords(address user) external view returns(Process.Record[] memory){
        return 
            IFinance(finance).getReferralAwardRecords(user);
    }

    function getDirectReferralInfo(address user) external view returns(Process.Info[] memory){
        return 
            IFinance(finance).getDirectReferralInfo(user);
    }

    function getAmountOut(uint256 amountUSDT) external view returns(uint256){
        return 
            IFinance(finance).getAmountOut(amountUSDT);
    }

    function totalStakedUsdt() external view returns(uint256){
        return 
            IFinance(finance).totalStakedUsdt();
    }

    function validReferralCode(address user) external view returns(bool){
        return 
            IFinance(finance).validReferralCode(user);
    }

    function referral(address recommender) external{
        IFinance(finance).referral(recommender, msg.sender);
    }

    function stake(uint256 amountUSDT) external{
        IFinance(finance).stake(msg.sender, amountUSDT);
    }

    function claim() external{
        IFinance(finance).claim(msg.sender);
    }

    function swapSubToken(uint256 amountUSDT) external{
        IFinance(finance).swapSubToken(msg.sender, amountUSDT);
    }

}