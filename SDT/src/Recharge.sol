// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";



contract Recharge is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{

    address public admin;
    address public operator;
    address public recipient;
    address public sender;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public constant factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    struct Info{
        address user;
        uint256 amount;
    }

    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);
    event MultiRecharge(address user, address token0, uint256 amount0, address token1, uint256 amount1, string remark);
    event Withdraw(string remark, address token, address to, uint256 amount);


    receive() external payable{}

    modifier onlyAdmin() {
        require(msg.sender == admin, "ERROR_ADMIN.");
        _;
    }

    modifier onlyOperator(){
        require(msg.sender == operator, "ERROR_ADMIN.");
        _;
    }

    function changeAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "ZERO_ADDRESS.");
        emit AdminshipTransferred(admin, _newAdmin);
        admin = _newAdmin;
    }

    function changeRecipient(address _newRecipient) external onlyAdmin {
        require(_newRecipient != address(0), "ZERO_ADDRESS.");
        recipient = _newRecipient;
    }

    function changeSender(address _newSender) external onlyAdmin(){
        require(_newSender != address(0), "ZERO_ADDRESS.");
        sender = _newSender;
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(
        address _admin,
        address _recipient,
        address _sender
    ) public initializer {
        __Ownable_init(_msgSender());
        admin = _admin;
        recipient = _recipient;
        sender = _sender;
    }

    function singleRecharge(address token, uint256 amount, string calldata remark) external payable {
        require(amount > 0, "ERROR_AMOUNT");

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = token;
        amounts[0] = amount;

        _recharge(tokens, amounts);

        // emit SingleRecharge(msg.sender, token, amount, remark);
        emit MultiRecharge(msg.sender, token, amount, address(0), 0, remark);
    }

    /**
     * @dev 双币充值（支持 ERC20 + ERC20 / ERC20 + ETH / ETH + ERC20 / ETH + ETH）
     */
    function multiRecharge(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        string calldata remark
    ) external payable {
        require(amount0 > 0 || amount1 > 0, "ERROR_AMOUNT");

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = token0;
        amounts[0] = amount0;
        tokens[1] = token1;
        amounts[1] = amount1;

        _recharge(tokens, amounts);

        emit MultiRecharge(msg.sender, token0, amount0, token1, amount1, remark);
    }

    function _recharge(address[] memory tokens, uint256[] memory amounts) internal {
        require(tokens.length == amounts.length, "MISMATCH_LENGTH");

        uint256 totalETHRequired = 0;
        bool hasETH = false;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            if (token == address(0)) {
                totalETHRequired += amount;
                hasETH = true;
            } else {
                TransferHelper.safeTransferFrom(token, msg.sender, recipient, amount);
            }
        }

        if (hasETH) {
            // 如果有 ETH 充值，必须满足金额要求
            require(msg.value >= totalETHRequired, "ERROR_PAYABLE_AMOUNT");
            if (totalETHRequired > 0) {
                TransferHelper.safeTransferETH(recipient, totalETHRequired);
            }

            // 多余 ETH 退回
            uint256 refund = msg.value - totalETHRequired;
            if (refund > 0) {
                TransferHelper.safeTransferETH(msg.sender, refund);
            }
        } else {
            // 如果没有 ETH 充值，则禁止传 ETH
            require(msg.value == 0, "NO_ETH_REQUIRED");
        }
    }

    function withdraw(string memory remark, address token, uint256 amount, address to) external onlyAdmin(){
        require(amount > 0,"ERROR_AMOUNT.");
        if(token != address(0)) TransferHelper.safeTransferFrom(token, sender, to, amount);
        else TransferHelper.safeTransferETH(to, amount);
        emit Withdraw(remark, token, to, amount);
    }


    function multiBalanceOf(address token, address[] calldata users) external view returns (Info[] memory) {
        uint256 len = users.length;
        Info[] memory infos = new Info[](len);

        if (token == address(0)) {
            // 查询 ETH 余额
            for (uint256 i = 0; i < len; i++) {
                infos[i] = Info({
                    user: users[i],
                    amount: users[i].balance
                });
            }
        } else {
            // 查询 ERC20 余额
            IERC20 tokenContract = IERC20(token);
            for (uint256 i = 0; i < len; i++) {
                infos[i] = Info({
                    user: users[i],
                    amount: tokenContract.balanceOf(users[i])
                });
            }
        }

        return infos;
    }

    function getPrice(address token) external view returns(address, uint256) {
        address pairWBNB = IUniswapV2Factory(factory).getPair(token, WBNB);
        address pairUSDT = IUniswapV2Factory(factory).getPair(token, USDT);

        uint256 amountIn = 1e18; // 假设 token 有 18 位精度
        uint256 amountOut;

        // 优先返回 USDT 交易对
        if(pairUSDT != address(0)) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = USDT;
            uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(amountIn, path);
            amountOut = amountsOut[amountsOut.length - 1]; 
            return (USDT, amountOut);
        }

        // 否则返回 WBNB 交易对
        if(pairWBNB != address(0)) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WBNB;
            uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(amountIn, path);
            amountOut = amountsOut[amountsOut.length - 1];
            return (WBNB, amountOut);
        }

        // 如果两个交易对都不存在，返回 0
        return (address(0), 0);
    }


}