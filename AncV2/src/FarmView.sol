// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./FarmCore.sol";
import "./FarmNode.sol";
import "./FarmReferral.sol";
import "./FarmToday.sol";
import "./libraries/Process.sol";

contract FarmView {

    FarmCore public immutable farmCore;
    FarmNode public immutable farmNode;
    FarmReferral public immutable farmReferral;
    FarmToday public immutable farmToday;

    constructor(
        FarmCore _farmCore,
        FarmNode _farmNode,
        FarmReferral _farmReferral,
        FarmToday _farmToday
    ) {
        farmCore = FarmCore(_farmCore);
        farmNode = FarmNode(_farmNode);
        farmReferral = FarmReferral(_farmReferral);
        farmToday = FarmToday(_farmToday);
    }

    function getAwardRecord(address user) external view returns(
        Process.Record[] memory node,
        Process.Record[] memory today,
        Process.Record[] memory invite
    ){
        node = farmNode.getAwardRecords(user);
        today = farmToday.getAwardRecords(user);
        invite = farmReferral.getAwardRecords(user);
    }

    // 获取直推地址信息
    function getDirectReferralAddrInfo(address user) external view returns(Process.Info[] memory infos) {
        address[] memory directs = farmReferral.getDirectReferralAddrs(user);
        infos = new Process.Info[](directs.length);

        for (uint i = 0; i < directs.length; i++) {
            address directAddr = directs[i];

            // 从 FarmCore 获取 stakingUsdt
            (
                ,uint256 stakingUsdt,,,,
            )  = farmCore.userInfo(directAddr);

            // 从 FarmReferral 获取 overall 和 effective
            (, , , uint256 overallPerformance, uint256 effectivePerformance, ) = farmReferral.referralInfo(directAddr);

            infos[i] = Process.Info({
                user: directAddr,
                stakingUsdt: stakingUsdt,
                overall: overallPerformance,
                effective: effectivePerformance
            });
        }
    }


    function getUserInfo(address user) external view returns(
        Process.NodeType nodeType,
        uint256 stakingUsdt,
        Process.StakingOrder[] memory orders,
        address recommender,
        uint256 overallPerformance,
        uint256 effectivePerformance,
        uint256 referralNum,
        uint256 ancAward,
        uint256 usdtAward
    ){
        (
            recommender,,,
            overallPerformance,
            effectivePerformance,
            referralNum
        ) = farmReferral.referralInfo(user);
        
        (
            nodeType,
            stakingUsdt,,,,
        )  = farmCore.userInfo(user);
    
        orders = farmCore.getUserOrders(user);

        (ancAward, usdtAward) = farmCore.getUserTruthAward(user);
        
    }
    
    function getUserOtherInfo(address user) external view returns(
        uint256 todayAward,
        uint256 nodeAward,
        uint256 referralAward,
        bool isRankAnc, //满足2万usdt参与分红，是否满足
        bool isRankUsdt //满足5万usdt参与分红anc，是否满足
    ){  
        (, referralAward,,,,) = farmReferral.referralInfo(user);
        todayAward = farmToday.usdtTodayAward(user);
        nodeAward = farmNode.usdtNodeAward(user);
        (isRankAnc, isRankUsdt) = farmReferral.getBelongToRank(user);
    }
    
    function getTodayTopInfo() external view returns(Process.Today[] memory){
        return farmToday.getTodayTopInfo();
    }

    function getInitialCode() external view returns(address){
        return farmReferral.initialCode();
    }

    function eligibilityCode(address user) external view returns(bool){
        // return userInfo[user].stakingUsdt > 0;
        (
            ,uint256 stakingUsdt,,,,
        )  = farmCore.userInfo(user);
        return stakingUsdt > 0;
    }

    function totalCumulateAward() external view returns(uint256){
        return farmCore.totalCumulateAward();
    }
}