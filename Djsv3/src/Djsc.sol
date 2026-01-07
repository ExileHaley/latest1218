// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract Djsc is ERC20, Ownable{
    event SwapAndSendTax(address recipient, uint256 tokensSwapped);
    IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    uint256 public sell_tax_rate = 3;
    uint256 public buy_tax_rate = 100;
    address public sellFee;
    address public buyFee;

    address public pancakePair;
    address public USDT;
    bool    private swapping;
    mapping(address => bool) public allowlist;

    constructor(
        address[4] memory addrs, 
        address _sellFee, 
        address _buyFee, 
        address _USDT
    )ERC20("DJSC","DJSC")Ownable(msg.sender){
        allocate(addrs);
        USDT = _USDT;
        sellFee = _sellFee;
        buyFee = _buyFee;

        allowlist[_sellFee] = true;
        allowlist[_buyFee] = true;

        pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), USDT);
    }
    
    function allocate(address[4] memory addrs) private{
        uint256[4] memory amounts = [
            uint256(3000000) * 1e18,
            uint256(4000000) * 1e18,
            uint256(3000000) * 1e18,
            uint256(90000000) * 1e18
        ];
        for(uint i=0; i<addrs.length; i++){
            _mint(addrs[i], amounts[i]);
            allowlist[addrs[i]] = true;
        }
    }

    function setTaxRate(uint256 _buyRate, uint256 _sellRate) external  onlyOwner{
        buy_tax_rate = _buyRate;
        sell_tax_rate = _sellRate;
    }

    function setAllowlist(address[] memory addrs, bool isAllow) external onlyOwner{
        for(uint i=0; i<addrs.length; i++){
            allowlist[addrs[i]] = isAllow;
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (swapping || from == address(0) || to == address(0) || allowlist[from] || allowlist[to]) {
            super._update(from, to, amount);
            return;
        }

        uint256 feeAmount = 0;
        if (from == pancakePair && buy_tax_rate > 0) {
            feeAmount = amount * buy_tax_rate / 100;
            if (feeAmount > 0) {
                super._update(from, buyFee, feeAmount);
            }
        }

        if (to == pancakePair && sell_tax_rate > 0) {
            feeAmount = amount * sell_tax_rate / 100;
            if (feeAmount > 0) {
                super._update(from, address(this), feeAmount);
                _swap(feeAmount, sellFee);
            }
        }

        uint256 sendAmount = amount - feeAmount;
        super._update(from, to, sendAmount);

    }

    function _swap(uint256 amountToken, address to) private{
        if (amountToken == 0) return ;
        //update status
        swapping = true;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;
        _approve(address(this), address(pancakeRouter), amountToken);
         try pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountToken,
            0, 
            path,
            to,
            block.timestamp + 30
        ) {
            emit SwapAndSendTax(to, amountToken);
        }catch{}
        //update status
        swapping = false;
    }

}