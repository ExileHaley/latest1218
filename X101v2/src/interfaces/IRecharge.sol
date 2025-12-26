// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILiquidity {
    struct Info{
        address user;
        uint256 amount;
    }
    enum Mark{INVAILD, ADD, REMOVE}

    event Liquidity(
        string remark,
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        address pair,
        uint256 liquidity,
        Mark    mark
    );

    event Exchange(
        string remark,
        address original,
        uint256 amount,
        address target,
        address from,
        address to
    );

    event MultiRecharge(
        string remark,
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    );

    event Withdraw(
        string remark, 
        address token, 
        address to, 
        uint256 amount
    );
    function setAllocation(address token, address[] calldata recipients, uint256[] calldata rates) external;
    function changeRecipient(address _newRecipient) external;
    function changeSender(address _newSender) external;
    function removeLiquidity(
        address token0, 
        address token1,
        uint256 amount, 
        address to, 
        string calldata remark
    ) external;
    function swapExactIn(
        address fromToken, 
        address targetToken, 
        uint256 fromAmount, 
        address from, 
        address to,
        string calldata remark
    ) external;
    function multiRecharge(
        address token0, 
        address token1, 
        uint256 amount0, 
        uint256 amount1, 
        string calldata remark
    ) external;
    function withdraw(string memory remark, address token, uint256 amount, address to) external;
    function multiBalanceOf(address token, address[] calldata users) external view returns (Info[] memory);
    function getPrice(address token) external view returns(address, uint256);
    function getAllowance(address token, address owner) external view  returns (uint256);
}