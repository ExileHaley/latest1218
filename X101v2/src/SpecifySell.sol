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
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

interface IBurn{
    function specificBurn(address account, address to, uint256 amount) external;
    function burnFromPair(uint256 amount) external;
}

contract SpecifySell is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    address public constant USDT = 0x3ea660cDc7b7CCC9F81c955f1F2412dCeb8518A5;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant ADX = 0x68a4d37635cdB55AF61B8e58446949fB21f384e5;
    address public gas;
    address public x101;

    address public uniswapV2Router;
    address public uniswapV2factory;

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(address _router,address _x101, address _gas) public initializer {
        __Ownable_init(_msgSender());
        uniswapV2Router = _router;
        x101 = _x101;
        gas = _gas;
        uniswapV2factory = IUniswapV2Router02(uniswapV2Router).factory();
    }

    function setTokenAddr(address _gas, address _x101) external onlyOwner{
        gas = _gas;
        x101 = _x101;
    }

    function sellForX101(uint256 amount) external{
        TransferHelper.safeTransferFrom(x101, msg.sender, address(this), amount);
        
        uint256 balanceBefore = IERC20(ADX).balanceOf(address(this));
        TransferHelper.safeApprove(x101, uniswapV2Router, amount);
        address[] memory path = new address[](2);
        path[0] = x101;
        path[1] = ADX;
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 30
        );

        uint256 amountForUser = IERC20(ADX).balanceOf(address(this)) - balanceBefore;
        //发送兑换结果
        TransferHelper.safeTransfer(ADX, msg.sender, amountForUser);

        //销毁gas
        uint256 amountGasForBurn = getAmountOut(amount);
        if(gas != address(0)) IBurn(gas).specificBurn(msg.sender, DEAD, amountGasForBurn);
        //销毁底池并且平衡价格
        IBurn(x101).burnFromPair(amount * 20 / 100);
        address x101Pair = IUniswapV2Factory(uniswapV2factory).getPair(x101, ADX); 
        IUniswapV2Pair(x101Pair).sync();
    }

    function getAmountOut(uint256 amount) public view returns(uint256){
        // address factory = pancakeRouter.factory();  
        address x101Pair = IUniswapV2Factory(uniswapV2factory).getPair(x101, ADX);      
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(x101Pair).getReserves();
        if(reserve0 > 0 && reserve1 > 0){
            address adxPair = IUniswapV2Factory(uniswapV2factory).getPair(ADX, USDT);
            if(adxPair != address(0)){
                (uint112 reserveADX, uint112 reserveUSDT,) = IUniswapV2Pair(adxPair).getReserves();
                if(reserveADX > 0 && reserveUSDT > 0){
                        address[] memory path = new address[](3);
                        path[0] = x101;
                        path[1] = ADX;
                        path[2] = USDT;
                        return IUniswapV2Router02(uniswapV2Router).getAmountsOut(amount, path)[2];
                }
            }
        }
        return 0;
    }

    function getAmountAdxOut(uint256 amount) external view returns(uint256){
        address[] memory path = new address[](2);
        path[0] = x101;
        path[1] = ADX;
        return IUniswapV2Router02(uniswapV2Router).getAmountsOut(amount, path)[1];
    }
}