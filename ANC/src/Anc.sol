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
    function updateFarmAnc(uint256 amount) external;
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
    address public recipient;
    address public farmCore;
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
        address _recipient,
        address _community,
        address _buyBack,
        address _USDT
    )ERC20("ANC","ANC")Ownable(msg.sender){
        _mint(_initialRecipient, 1000000000e18);
        recipient = _recipient;
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

    modifier onlyFarmCore() {
        require(farmCore == msg.sender, "Not permit.");
        _;
    }


    function setFeeRate(uint256 _sellRate, uint256 _buyRate) external onlyOwner{
        sell_fee_rate = _sellRate;
        buy_fee_rate = _buyRate;
    }

    function setFarmCore(address _farmCore) external onlyOwner{
        farmCore = _farmCore;
        allowlist[_farmCore] = true;
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

            if(farmCore != address(0)){
                uint256 feeAmountPercent20 = feeAmount * 20 / 100;
                uint256 feeAmountPercent30 = feeAmount * 30 / 100;
                _swap(feeAmountPercent20, community);
                _swap(feeAmountPercent30, buyBack);
                uint256 beforeAmount = IERC20(USDT).balanceOf(farmCore);
                _swap(feeAmount - feeAmountPercent20 - feeAmountPercent30, farmCore);
                uint256 afterAmount = IERC20(USDT).balanceOf(farmCore);
                IFarm(farmCore).updateFarmUsdt(afterAmount - beforeAmount);
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

    
    function burnFromPair() external onlyFarmCore returns (uint256) {
        require(farmCore != address(0), "FARM_NOT_SET");
        require(recipient != address(0), "INVALID_RECIPIENT");
        require(totalSupply() - balanceOf(DEAD) > 10_000_000e18, "STOP_ISSUE");

        // 1. calc days
        uint256 realDays = (block.timestamp - latestBurnTime) / 1 days;
        if (realDays == 0) return 0;

        uint256 pairBalance = balanceOf(pancakePair);
        if(pairBalance == 0) return 0;

        // 2. limit 3%
        uint256 totalAmount = pairBalance * TOTAL_BURN_RATE / 100;
        if (totalAmount == 0) return 0;

        // 3. 10% => recipient
        uint256 recipientAmount = totalAmount * 10 / 100;
        uint256 remainAmount = totalAmount - recipientAmount;

        // 4. calc and limit farm rate
        uint256 newIssueRate = issueRate + ADD_ISSUE_RATE * realDays;
        if (newIssueRate > 8000) {
            newIssueRate = 8000;
        }

        uint256 farmAmount = remainAmount * newIssueRate / 10000;
        uint256 burnAmount = remainAmount - farmAmount;

        // 5. anc from pair to address(this)
        super._update(pancakePair, address(this), totalAmount);

        // 6. send to recipient
        if (recipientAmount > 0) {
            super._update(address(this), recipient, recipientAmount);
        }

        // 7. send to farm
        if (farmAmount > 0) {
            super._update(address(this), farmCore, farmAmount);
        }

        // 8. send to dead
        if (burnAmount > 0) {
            super._update(address(this), DEAD, burnAmount);
        }

        // 9. update status
        issueRate = newIssueRate;
        latestBurnTime += realDays * 1 days;

        emit BurnFromPair(
            realDays,
            totalAmount,
            farmAmount,
            burnAmount,
            issueRate
        );

        return farmAmount;
    }




}