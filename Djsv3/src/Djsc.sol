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
  
    uint256 public constant PROFIT_TAX_RATE = 10;
    uint256 public sell_tax_rate = 3;
    uint256 public buy_tax_rate = 3;
    address public sellFee;
    address public buyFee;
    address public profitFee;

    address public pancakePair;
    address public USDT;
    bool    private swapping;
    mapping(address => bool) public allowlist;
    mapping(address => uint256) public totalCostUsdt;
    
    constructor(
        address[4] memory addrs, 
        address _sellFee, 
        address _buyFee, 
        address _profitFee,
        address _USDT
    )ERC20("DJSC","DJSC")Ownable(msg.sender){
        allocate(addrs);
        USDT = _USDT;
        sellFee = _sellFee;
        buyFee = _buyFee;
        profitFee = _profitFee;

        allowlist[_sellFee] = true;
        allowlist[_buyFee] = true;
        allowlist[_profitFee] = true;

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

        bool isBuy = from == pancakePair;
        bool isSell = to == pancakePair;

        if (isBuy) {
            _handleBuy(from, to, amount);
            return;
        }

        if (isSell) {
            _handleSell(from, to, amount);
            return;
        }

        uint256 balanceToken = balanceOf(address(this));
        if (balanceToken > 0) {
            _swap(balanceToken, buyFee);
        }


        uint256 balanceBefore = balanceOf(from);
        uint256 costBefore = totalCostUsdt[from];

        super._update(from, to, amount);

        if (costBefore > 0 && balanceBefore > 0) {
            uint256 migratedCost = costBefore * amount / balanceBefore;


            totalCostUsdt[from] = costBefore - migratedCost;
            if (totalCostUsdt[from] < 1e6) {
                totalCostUsdt[from] = 0;
            }


            totalCostUsdt[to] += migratedCost;
        }

    }

    function _handleBuy(address from, address to, uint256 amount) private {
        uint256 buyFeeAmount = amount * buy_tax_rate / 100;
        uint256 toAmount = amount - buyFeeAmount;

        _updateCost(to, amount + (amount * 25 / 1000));

        super._update(from, address(this), buyFeeAmount);

        super._update(from, to, toAmount);
    }

    function _handleSell(address from, address to, uint256 amount) private {

        uint256 balanceBefore = balanceOf(from);

        uint256 sellFeeAmount = amount * sell_tax_rate / 100;
        uint256 toAmount = amount - sellFeeAmount;

        uint256 taxAmount = getProfitTaxToken(from, toAmount);

        if (taxAmount > 0 ) {
            super._update(from, address(this), taxAmount);
            _swap(taxAmount, profitFee);
        }

        super._update(from, address(this), sellFeeAmount);
        _swap(sellFeeAmount, sellFee);

        super._update(from, to, toAmount - taxAmount);


        uint256 balanceAfter = balanceOf(from);
        if (balanceAfter == 0) {
            totalCostUsdt[from] = 0;
        } else {
            uint256 costBefore = totalCostUsdt[from];
            uint256 costRemoved = costBefore * amount / balanceBefore;
            totalCostUsdt[from] = costBefore - costRemoved;

            if (totalCostUsdt[from] < 1e6) {
                totalCostUsdt[from] = 0;
            }
        }

    }

    function getAmountOut(uint256 amountToken) public view returns(uint256){
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;
        uint256[] memory amounts = pancakeRouter.getAmountsOut(amountToken, path);
        return amounts[1];
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

    function currentPrice() public view returns (uint256) {
        // uint256 lp = IERC20(pancakePair).totalSupply();
        // if(lp == 0) return 0;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;
        return pancakeRouter.getAmountsOut(1e18, path)[1];
    }

    function averagePriceOf(address user) public view returns (uint256) {
        uint256 bal = balanceOf(user);
        if (bal == 0) return 0;
        return totalCostUsdt[user] * 1e18 / bal;
    }

    function _updateCost(address to, uint256 amountToken) private{
        if (to == address(pancakeRouter) || to == pancakePair) {
            return;
        }
        uint256 price = currentPrice(); // USDT / token
        uint256 costUsdt = price * amountToken / 1e18;
        totalCostUsdt[to] += costUsdt;
    }

    function getProfitTaxToken(
        address from,
        uint256 amountToken
    ) public view returns (uint256 taxToken) {
        if (amountToken == 0) return 0;

        uint256 avg = averagePriceOf(from);
        if (avg == 0) return 0;

        uint256 price = currentPrice();
        if (price <= avg) return 0;

        // 盈利部分对应 token 数量
        uint256 profitToken = amountToken * (price - avg) / price;

        taxToken = profitToken * PROFIT_TAX_RATE / 100;

        if (taxToken > amountToken) {
            // taxToken = amountToken * totalProfitRate / 100;
            // taxToken = 0;
            taxToken = amountToken * PROFIT_TAX_RATE / 100;
        }

        return taxToken;
    }
}