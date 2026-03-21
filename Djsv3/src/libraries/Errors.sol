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

    error InsufficientLiquidity();  
    error AmountTooLow();          
    
    error PairNotExist();         
    error NotRequiredReferral();   
    error NoMigrationRequired();  
    error AlreadyMigrated();    
    error NoStake();        
}