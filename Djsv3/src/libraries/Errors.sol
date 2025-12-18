// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Errors {
    
    // error PauseError();
    // error PairNotExists();
    // error NotAuthorized();
    // error AmountZero();
    // error TransferFailed();
    // error NotStarted();
    // error ExceededLimit();
    // error NotHolder();
    error DivByZero();
    error InvalidAmount();
    error InsufficientQuota();
    error ZeroAddress();
    error InvalidRecommender();
    error NeedMigrate();
    error NoLiquidity();
    error InviterExists();
    error InsufficientLP();
    error NoReward();

    error InsufficientLiquidity();   // 新增错误：流动性不足
    error AmountTooLow();            // 新增错误：金额太小
    
    error PairNotExist();            //pair不存在
    error NotRequiredReferral();     //质押时必须要邀请关系
    error NoMigrationRequired();     //不需要映射
    error AlreadyMigrated();         //已经映射
    error NoStake();                 //没有质押
}