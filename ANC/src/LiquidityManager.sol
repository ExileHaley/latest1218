// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
// import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

contract LiquidityManager is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    event Redeem(address user, uint256 amountUsdt, uint256 amountAnc, uint256 amountBurn);
    event Liquidity(address user, uint256 amountLP);
    IUniswapV2Router02 public constant pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public USDT;
    address public tokenAnc;
    address public uniswapV2Factory;
    address public farm;
    uint256 public latestUpdatePrice;

    uint256 public constant PRECISION = 1e18; // 100%
    uint256 constant ONE_PERCENT = 1e16;
    uint256 limitDown; // 10%

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    modifier onlyCore() {
        require(farm == msg.sender, "Not permit.");
        _;
    }

    function initialize(
        address _USDT,
        address _tokenAnc
    ) public initializer {
        __Ownable_init(_msgSender());
        USDT = _USDT;
        tokenAnc = _tokenAnc;
        uniswapV2Factory = pancakeRouter.factory();
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function setFarmCore(address _farm) external onlyOwner{
        farm = _farm;
    }

    function setLimitDown(uint256 _limitDown) external onlyCore(){
        limitDown = _limitDown * ONE_PERCENT;
        latestUpdatePrice = getAmountOut();
    }

    function _exchange(address fromToken, address toToken, uint256 amount) internal{
        TransferHelper.safeApprove(fromToken, address(pancakeRouter), 0);
        TransferHelper.safeApprove(fromToken, address(pancakeRouter), amount);
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 30
        );
    }

    function addLiquidity(address to, uint256 amountUSDT) external onlyCore returns(uint256){
        uint256 oneHalf = amountUSDT / 2;
        uint256 beforeBalance = IERC20(tokenAnc).balanceOf(address(this));
        _exchange(USDT, tokenAnc, oneHalf);
        uint256 afterBalance = IERC20(tokenAnc).balanceOf(address(this));

        uint256 toLiquidityUSDT = amountUSDT - oneHalf;
        uint256 toLiquidityToken = afterBalance - beforeBalance;

        IERC20(USDT).approve(address(pancakeRouter), toLiquidityUSDT);
        IERC20(tokenAnc).approve(address(pancakeRouter), toLiquidityToken);

        (,,uint liquidity) = pancakeRouter.addLiquidity(
            USDT,
            tokenAnc,
            toLiquidityUSDT,
            toLiquidityToken,
            0,
            0,
            address(this),
            block.timestamp + 30
        );
        emit Liquidity(to, liquidity);
        return liquidity;
    }

    function redeemLiquidity(address to, uint256 stakingTime, uint256 amountLP) external onlyCore(){
        uint256 duration = (block.timestamp - stakingTime) / 1 days;
        if(duration >= 50)  duration = 50;

        address pair = IUniswapV2Factory(uniswapV2Factory).getPair(USDT, tokenAnc);
        _removeLiquidity(pair, amountLP);

        uint256 amountTokenAnc = IERC20(tokenAnc).balanceOf(address(this));
        uint256 amountUsdt = IERC20(USDT).balanceOf(address(this));
        uint256 amountTo = amountTokenAnc * duration / 100;
        if(amountTo > 0) TransferHelper.safeTransfer(tokenAnc, to, amountTo);
        TransferHelper.safeTransfer(tokenAnc, DEAD, amountTokenAnc - amountTo);
        TransferHelper.safeTransfer(USDT, to, amountUsdt);
        emit Redeem(to, amountUsdt, amountTo, amountTokenAnc - amountTo);
    }

    function _removeLiquidity(address pair, uint256 amountLP) private{
        TransferHelper.safeApprove(pair, address(pancakeRouter), amountLP);
        IUniswapV2Router02(pancakeRouter).removeLiquidity(
            tokenAnc, 
            USDT, 
            amountLP, 
            0, 
            0, 
            address(this), 
            block.timestamp
        );
    }


    
    
    function isLimitDownTriggered() public view returns (bool) {
        uint256 currentPrice = getAmountOut();
        uint256 lastPrice = latestUpdatePrice;

        if (lastPrice == 0 || limitDown == 0 || currentPrice >= lastPrice) {
            return false; // 没下跌，不触发
        }

        uint256 drop = lastPrice - currentPrice;
        // 下跌 >= limitDown → true
        return drop * PRECISION >= lastPrice * limitDown;
    }


    function getAmountOut() public view returns(uint256){
        address[] memory path = new address[](2);
        path[0] = tokenAnc;
        path[1] = USDT;
        return pancakeRouter.getAmountsOut(1e18, path)[1];
    }

    function exchange(address from) external onlyCore(){
        uint256 balance = IERC20(USDT).balanceOf(from);
        if(isLimitDownTriggered() && balance > 0){
            uint256 buyAmount = balance / 2;
            TransferHelper.safeTransferFrom(USDT, from, address(this), buyAmount);
            _exchange(USDT, tokenAnc, buyAmount);
            latestUpdatePrice = getAmountOut();
        }
    }

}
