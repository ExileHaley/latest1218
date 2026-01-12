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
}