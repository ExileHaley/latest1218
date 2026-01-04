// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Finance.sol";
import "./libraries/Process.sol";

contract FinanceView {

    Finance public immutable finance;

    constructor(Finance _finance) {
        finance = Finance(_finance);
    }

    function getUserInfoBasic(address user)
        external
        view
        returns (
            uint256 stakingUsdt,
            uint256 extracted,
            uint256 remaining,
            uint256 stakingAward,
            uint256 extractable,
            uint256 referralAward,
            uint256 shareAward
        )
    {   
        (stakingUsdt,,,extracted,) = finance.userInfo(user);
        (,,,,referralAward,shareAward,,) = finance.referralInfo(user);

        //剩余待释放
        uint256 futureTotalAward = stakingUsdt * finance.MULTIPLE();
        if(futureTotalAward >= extracted) remaining = futureTotalAward - extracted;
        else remaining = 0;    

        stakingAward = finance.getUserStakingAward(user);
        extractable = finance.getUserAward(user);

    }


    function getUserInfoReferral(address user)
        external
        view
        returns (
            Process.Level level,
            address recommender,
            uint256 referralNum,
            uint256 performance,
            uint256 subCoinQuota
        )
    {
        (recommender,level,referralNum,performance,,,subCoinQuota,) = finance.referralInfo(user);
    }

    // function getDirectReferralInfo(address user)
    //     external
    //     view
    //     returns (Process.Info[] memory infos)
    // {
    //     address[] memory refs = finance.directReferrals(user);
    //     uint256 len = refs.length;
    //     infos = new Process.Info[](len);

    //     for (uint256 i; i < len; ++i) {
    //         address u = refs[i];
    //         infos[i] = Process.Info({
    //             user: u,
    //             amount: finance.userInfo(u).stakingUsdt
    //                     + finance.referralInfo(u).performance
    //         });
    //     }
    // }


    
}
