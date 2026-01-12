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

interface IFarm {
    function updateFarmUsdt(uint256 amount) external;
    function updateFarmToken(uint256 amount) external;
}

contract Anc is ERC20, Ownable{
    event SwapAndSendTaxResult(address recipient, uint256 tokensSwapped, bool swapped);
    IUniswapV2Router02 public pancakeRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public sell_fee_rate = 10;
    uint256 public buy_fee_rate = 100;

    //addr config
    address public community; //20%
    address public buyBack; //30%
    address public farm;
    //mainnet config
    address public pancakePair;
    address public USDT;
    
    mapping(address => bool) public allowlist;

    //burn config
    uint256 public constant TOTAL_BURN_RATE = 3;      // 3% /100
    uint256 public constant ADD_ISSUE_RATE = 5;       // 5 /10000
    uint256 public issueRate = 2000;                  // 20% = 2000 /10000

    uint256 public latestBurnTime;

    bool    private swapping;

    constructor(
        address _initialRecipient, 
        address _community,
        address _buyBack,
        address _USDT
    )ERC20("ANC","ANC")Ownable(msg.sender){
        _mint(_initialRecipient, 1000000000e18);
        community = _community;
        buyBack = _buyBack;
        allowlist[_initialRecipient] = true;
        allowlist[community] = true;
        allowlist[buyBack] = true;
        USDT = _USDT;
        
        pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), USDT);

        latestBurnTime = block.timestamp;
    }


    function setFeeRate(uint256 _sellRate, uint256 _buyRate) external onlyOwner{
        sell_fee_rate = _sellRate;
        buy_fee_rate = _buyRate;
    }

    function setFarmCore(address _farm) external onlyOwner{
        farm = _farm;
        allowlist[_farm] = true;
    }

    function setAllowlist(address user, bool isAllow) external onlyOwner{
        allowlist[user] = isAllow;
    }

    function _update(address from, address to, uint256 amount) internal virtual override{
        if (swapping || from == address(0) || to == address(0) || allowlist[from] || allowlist[to]) {
            super._update(from, to, amount);
            return;
        }

        bool isBuy = from == pancakePair;
        bool isSell = to == pancakePair;
        uint256 feeAmount = 0;

        if(isBuy){
            feeAmount = amount * buy_fee_rate / 100;
            super._update(from, DEAD, feeAmount);
        }

        if(isSell){
            feeAmount = amount * sell_fee_rate / 100;
            super._update(from, address(this), feeAmount);
            if(farm != address(0)){
                uint256 feeAmountPercent20 = feeAmount * 20 / 100;
                uint256 feeAmountPercent30 = feeAmount * 30 / 100;
                _swap(feeAmountPercent20, community);
                _swap(feeAmountPercent30, buyBack);
                uint256 beforeAmount = IERC20(USDT).balanceOf(farm);
                _swap(feeAmount - feeAmountPercent20 - feeAmountPercent30, farm);
                uint256 afterAmount = IERC20(USDT).balanceOf(farm);
                IFarm(farm).updateFarmUsdt(afterAmount - beforeAmount);
            }
        }

        super._update(from, to, amount - feeAmount);
    } 


    function _swap(uint256 amountToken, address to) private{
        if (amountToken == 0) return ;
        //update status
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT;
        _approve(address(this), address(pancakeRouter), 0);
        _approve(address(this), address(pancakeRouter), amountToken);
        bool success;
        swapping = true;
        try pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountToken,
            0, 
            path,
            to,
            block.timestamp + 30
        ) { 
            success = true;    
        }catch{
            success = false;
        }
        emit SwapAndSendTaxResult(to, amountToken, success);
        //update status
        swapping = false;
    }

    event BurnFromPair(
        uint256 daysPassed,
        uint256 totalAmount,
        uint256 farmAmount,
        uint256 burnAmount,
        uint256 newIssueRate
    );

    //分发模块新增80%的上限
    //70%静态
    //20%分业绩
    //10%打给一个地址
    function burnFromPair() external {
        require(farm != address(0), "FARM_NOT_SET");
        require(totalSupply() - balanceOf(DEAD) > 21_000_000e18, "STOP_ISSUE");
        uint256 passedDays = (block.timestamp - latestBurnTime) / 1 days;
        if(passedDays == 0) return;
        
        uint256 pairBalance = balanceOf(pancakePair);
        require(pairBalance > 0, "PAIR_EMPTY");

        // current total rate
        uint256 totalRate = passedDays * TOTAL_BURN_RATE; // 3% * days
        if (totalRate > 100) {
            totalRate = 100; // max rate limit
        }

        uint256 totalAmount = pairBalance * totalRate / 100;
        if(totalAmount == 0) return;

        // 2. farm rate / 10000
        uint256 farmRate = issueRate + ADD_ISSUE_RATE * passedDays;
        if (farmRate > 10000) {
            farmRate = 10000;
        }

        uint256 farmAmount = totalAmount * farmRate / 10000;
        uint256 burnAmount = totalAmount - farmAmount;

        // 3. token from pair to this.
        super._update(pancakePair, address(this), totalAmount);

        // 4. token to farm.
        if (farmAmount > 0) {
            super._update(address(this), farm, farmAmount);
            IFarm(farm).updateFarmToken(farmAmount);
        }

        // 5. token to dead.
        if (burnAmount > 0) {
            super._update(address(this), DEAD, burnAmount);
        }

        // 6. sync issueRate 
        issueRate += ADD_ISSUE_RATE * passedDays;
        if (issueRate > 10000) {
            issueRate = 10000;
        }

        // 7. sync time
        latestBurnTime += passedDays * 1 days;

        emit BurnFromPair(
            passedDays,
            totalAmount,
            farmAmount,
            burnAmount,
            issueRate
        );

    }



}