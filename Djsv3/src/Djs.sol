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

interface INodeDividends {
    function updateFarm(uint256 amount) external;
}

// interface IPancakePair {
//     function token0() external view returns (address);
//     function token1() external view returns (address);
//     function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
//     function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
// }


contract Djs is ERC20, Ownable{
    event SwapAndSendTax(address recipient, uint256 tokensSwapped);
    IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant SWAP_DEAD_FEE_RATE = 2;
    uint256 public constant SWAP_NODE_FEE_RATE = 3;
    uint256 public constant PROFIT_MARKET_TAX_RATE = 20;
    uint256 public constant PROFIT_NODE_TAX_RATE = 10;
    uint256 public constant PROFIT_WALLET_TAX_RATE = 5;

    //pair
    address public pancakePair;
    address public USDT;

    address public marketing;
    address public nodeDividends;
    address public wallet;

    bool    private swapping;
    bool    public  tradingOpen;

    mapping(address => bool) public allowlist;
    mapping(address => uint256) public totalCostUsdt;


    constructor(address _initialRecipient, address _marketing, address _wallet, address _USDT)ERC20("DJS","DJS")Ownable(msg.sender){
        _mint(_initialRecipient, 6870000e18);
        
        allowlist[_initialRecipient] = true;
        allowlist[_marketing] = true;
        allowlist[_wallet] = true;
        marketing = _marketing;
        wallet    = _wallet;
        USDT = _USDT;
        
        pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), USDT);
    }

    function setTradingOpen(bool _tradingOpen) external onlyOwner(){
        tradingOpen = _tradingOpen;
    }

    function setNodeDividends(address _nodeDividends) external onlyOwner{
        nodeDividends = _nodeDividends;
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
            _swapAndDistribute(balanceToken);
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
        require(tradingOpen, "BUY_AND_SELL_ISDISABLED.");

        uint256 deadFee = amount * SWAP_DEAD_FEE_RATE / 100;
        uint256 nodeFee = amount * SWAP_NODE_FEE_RATE / 100;
        uint256 toAmount = amount - deadFee - nodeFee;

        _updateCost(to, amount + (amount * 25 / 1000));

        super._update(from, address(this), nodeFee);
        super._update(from, DEAD, deadFee);


        super._update(from, to, toAmount);
    }


    function _handleSell(address from, address to, uint256 amount) private {
        require(tradingOpen, "BUY_AND_SELL_ISDISABLED.");
        uint256 balanceBefore = balanceOf(from);
        uint256 deadFee = amount * SWAP_DEAD_FEE_RATE / 100;
        uint256 nodeFee = amount * SWAP_NODE_FEE_RATE / 100;
        uint256 toAmount = amount - deadFee - nodeFee;

   
        uint256 taxAmount = getProfitTaxToken(from, toAmount);

        if (taxAmount > 0 ) {
            super._update(from, address(this), taxAmount);
            _distributeProfitTax(taxAmount);
        }

        
        super._update(from, address(this), nodeFee);
        super._update(from, DEAD, deadFee);

        
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

    function _distributeProfitTax(uint256 taxAmount) private {
        uint256 marketingPortion = taxAmount * 57 / 100;
        uint256 walletPortion    = taxAmount * 28 / 100;
        uint256 nodePortion      = taxAmount - marketingPortion - walletPortion;
        _swap(marketingPortion, marketing);
        _swap(walletPortion, wallet);

        if(nodeDividends != address(0)){
            _swap(nodePortion, nodeDividends);
            INodeDividends(nodeDividends).updateFarm(getAmountOut(nodePortion));
        }else{
             _swap(nodePortion, wallet);
        }
        
    }

    function _swapAndDistribute(uint256 amountToken) private {
        
        if(nodeDividends != address(0)){
            _swap(amountToken, nodeDividends);
            INodeDividends(nodeDividends).updateFarm(getAmountOut(amountToken));
        }else{
            _swap(amountToken, wallet);
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

        uint256 totalProfitRate =
            PROFIT_MARKET_TAX_RATE +
            PROFIT_NODE_TAX_RATE +
            PROFIT_WALLET_TAX_RATE;


        uint256 profitToken = amountToken * (price - avg) / price;

        taxToken = profitToken * totalProfitRate / 100;

        if (taxToken > amountToken) {
            // taxToken = amountToken * totalProfitRate / 100;
            taxToken = 0;
        }

        return taxToken;
    }

}