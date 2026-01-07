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

contract Djs is ERC20, Ownable{
    event SwapAndSendTax(address recipient, uint256 tokensSwapped);
    IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant SWAP_DEAD_FEE_RATE = 2;
    uint256 public constant SWAP_NODE_FEE_RATE = 3;

    uint256 public constant PROFIT_MARKET_TAX_RATE = 20;
    uint256 public constant PROFIT_NODE_TAX_RATE = 10;
    uint256 public constant PROFIT_WALLET_TAX_RATE = 5;

    address public pancakePair;
    address public USDT;

    address public sellAndProfit;
    address public walletForProfit;
    address public nodeDividends;
    
    bool    private swapping;
    bool    public  tradingOpen;

    mapping(address => bool) public allowlist;
    mapping(address => uint256) public totalCostUsdt;

    constructor(address _initialRecipient, address _sellAndProfit, address _walletForProfit, address _USDT)ERC20("DJS","DJS")Ownable(msg.sender){
        _mint(_initialRecipient, 6870000e18);
        
        allowlist[_initialRecipient] = true;
        allowlist[_sellAndProfit] = true;
        allowlist[_walletForProfit] = true;
        sellAndProfit = _sellAndProfit;
        walletForProfit = _walletForProfit;
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

    function getAmountOut(uint256 amountToken) public view returns(uint256){
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;
        uint256[] memory amounts = pancakeRouter.getAmountsOut(amountToken, path);
        return amounts[1];
    }

    function currentPrice() public view returns (uint256) {
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
            taxToken = 0;
        }

        return taxToken;
    }

    function _updateCost(address to, uint256 amountToken) private{
        if (to == address(pancakeRouter) || to == pancakePair) {
            return;
        }
        uint256 price = currentPrice(); // USDT / token
        uint256 costUsdt = price * amountToken / 1e18;
        totalCostUsdt[to] += costUsdt;
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
            if(nodeDividends != address(0)) _processToNodeFee(balanceToken); 
        }

        uint256 balanceBefore = balanceOf(from);
        uint256 costBefore = totalCostUsdt[from];

        super._update(from, to, amount);

        if (costBefore > 0 && balanceBefore > 0) {
            uint256 migratedCost = costBefore * amount / balanceBefore;


            totalCostUsdt[from] = costBefore - migratedCost;
            if (totalCostUsdt[from] < 1e15) {
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
        //profit for node
        super._update(from, address(this), nodeFee);

        super._update(from, DEAD, deadFee);
        super._update(from, to, toAmount);
    }

    function _handleSell(address from, address to, uint256 amount) private {
        require(tradingOpen, "BUY_AND_SELL_ISDISABLED.");
        uint256 balanceBefore = balanceOf(from);
        //sell fee
        uint256 sellFee = amount *(SWAP_DEAD_FEE_RATE + SWAP_NODE_FEE_RATE) / 100;
        //send to user
        uint256 toAmount = amount - sellFee;
        //calc profit amount
        uint256 taxAmount = getProfitTaxToken(from, toAmount);

        if (taxAmount > 0 ) {
            //send to contract
            super._update(from, address(this), taxAmount);
            //swap 57% for sellAndProfit
            _swap(taxAmount * 57 / 100, sellAndProfit);
            //swap 15% for walletForProfit
            _swap(taxAmount * 15 / 100, walletForProfit);
            //profit for node = taxAmount - 57% - 15%
        }
        //send sell fee 
        super._update(from, address(this), sellFee);  
        //swap sell fee for sellAndProfit
        _swap(sellFee, sellAndProfit);    
        //send to truth aamount
        super._update(from, to, toAmount - taxAmount);

        uint256 balanceAfter = balanceOf(from);
        if (balanceAfter == 0) {
            totalCostUsdt[from] = 0;
        } else {
            uint256 costBefore = totalCostUsdt[from];
            uint256 costRemoved = costBefore * amount / balanceBefore;
            totalCostUsdt[from] = costBefore - costRemoved;

            if (totalCostUsdt[from] < 1e15) {
                totalCostUsdt[from] = 0;
            }
        }

    }

    function _processToNodeFee(uint256 amount) internal{
        uint256 beforeUsdtAmount = IERC20(USDT).balanceOf(nodeDividends);
        _swap(amount, nodeDividends);
        uint256 afterUsdtAmount = IERC20(USDT).balanceOf(nodeDividends);
        INodeDividends(nodeDividends).updateFarm(afterUsdtAmount - beforeUsdtAmount);
    } 

    function processNodeFee() external{
        if(nodeDividends != address(0)){
            uint256 balanceToken = balanceOf(address(this));
            if(balanceToken > 0) {
                uint256 beforeUsdtAmount = IERC20(USDT).balanceOf(nodeDividends);
                _swap(balanceToken, nodeDividends);
                uint256 afterUsdtAmount = IERC20(USDT).balanceOf(nodeDividends);
                INodeDividends(nodeDividends).updateFarm(afterUsdtAmount - beforeUsdtAmount);
            }
        }
    }


}