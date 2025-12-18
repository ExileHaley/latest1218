// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILiquidity{
    function swapForSubTokenToUser(address to, uint256 amountUSDT) external;
    function swapForSubTokenToBurn(uint256 amountUSDT) external;
    function addLiquidity(uint256 amountUSDT) external;
    function acquireSpecifiedUsdt(address to, uint256 amountUSDT) external;
}