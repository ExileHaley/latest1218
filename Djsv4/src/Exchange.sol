// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract Exchange is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    event ExhcangeResult(address user, uint256 originalValue, uint256 targetValue);
    IUniswapV2Router02 public constant pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant DJS = 0xf273F77b4b88bB85E884a0E4521Cc091276B8cAE;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public admin;
    address public recipient;

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "ERROR_PERMIT.");
        _;
    }

    function initialize(
        address _admin,
        address _recipient
    ) public initializer {
        __Ownable_init(_msgSender());
        admin = _admin;
        recipient = _recipient;
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function setAdmin(address newAdmin) external onlyOwner {
        admin = newAdmin;
    }

    function setRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "ZERO_ADDRESS");
        recipient = _recipient;
    }



    function _executeSwap(address fromToken, address toToken, uint256 fromAmount) private{
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        
        // 执行 token → USDT 的交换
        TransferHelper.safeApprove(fromToken, address(pancakeRouter), 0);
        TransferHelper.safeApprove(fromToken, address(pancakeRouter), fromAmount);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            fromAmount,
            0,
            path,
            address(this),
            block.timestamp + 30
        );
    }

    function exhcange(uint256 amountDJS) external nonReentrant(){
        require(amountDJS > 0, "ZERO_AMOUNT");
        TransferHelper.safeTransferFrom(DJS, msg.sender, address(this), amountDJS);
        uint256 beforeExhcange = IERC20(USDT).balanceOf(address(this));
        _executeSwap(DJS, USDT, amountDJS);
        uint256 afterExchange = IERC20(USDT).balanceOf(address(this));
        uint256 fee = (afterExchange - beforeExhcange) * 5 / 100;
        uint256 amount = afterExchange - beforeExhcange - fee;
        TransferHelper.safeTransfer(USDT, recipient, fee);
        TransferHelper.safeTransfer(USDT, msg.sender, amount);
        emit ExhcangeResult(msg.sender, amountDJS, amount);
    }


    function getAmountsOut(uint256 amountDJS) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = DJS;
        path[1] = USDT;

        uint256[] memory amounts = pancakeRouter.getAmountsOut(amountDJS, path);
        return amounts[1] * 95 / 100;
    }

    function emergencyWithdraw(address token, uint256 amount, address to) external onlyAdmin {
        TransferHelper.safeTransfer(token, to, amount);
    }
}