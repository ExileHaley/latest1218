// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
library Process {
    enum NodeType { INVALID, SMALL, MEDIUM, LARGE }
    enum Token {INVALID, USDT_TOKEN, ANC_TOKEN}
    struct Record {
        Token token;
        address from;
        uint256 amount;
        uint256 time;
    }

    struct Info{
        address user;
        uint256 stakingUsdt;
        uint256 overall;
        uint256 effective;
    }
    
    struct Today{
        address user;
        uint256 performance;
    }

    struct StakingOrder{
        uint256 stakingUsdt;
        uint256 stakingLiquidity;
        uint256 stakingTime;
        bool    withdrawn;
    }
}