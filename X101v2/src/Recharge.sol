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


contract Recharge is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    address public constant WBNB = 0xe901E30661dD4Fd238C4Bfe44b000058561a7b0E;
    address public constant USDT = 0x3ea660cDc7b7CCC9F81c955f1F2412dCeb8518A5;

    enum Mark{INVAILD, ADD, REMOVE}

    event Liquidity(
        string remark,
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        address pair,
        uint256 liquidity,
        Mark    mark
    );

    event Exchange(
        string remark,
        address original,
        uint256 amount,
        address target,
        address from,
        address to
    );

    event MultiRecharge(
        string remark,
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    );

    event Withdraw(
        string remark, 
        address token, 
        address to, 
        uint256 amount
    );

    struct Allocation{
        address[] recipients;
        uint256[] rates;
    }
    mapping(address => Allocation) allocationInfo;

    struct Info{
        address user;
        uint256 amount;
    }

    address public uniswapV2Router;
    address public uniswapV2factory;
    address public admin;
    address public recipient;
    address public sender;
    
    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    modifier onlyAdmin() {
        require(admin == msg.sender,"Not permit.");
        _;
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(address _router,address _admin, address _recipient, address _sender) public initializer {
        __Ownable_init(_msgSender());
        uniswapV2Router = _router;
        admin = _admin;
        recipient = _recipient;
        sender = _sender;
        uniswapV2factory = IUniswapV2Router02(uniswapV2Router).factory();
    }

    function changeRecipient(address _newRecipient) external onlyAdmin {
        require(_newRecipient != address(0), "ZERO_ADDRESS.");
        recipient = _newRecipient;
    }

    function changeSender(address _newSender) external onlyAdmin(){
        require(_newSender != address(0), "ZERO_ADDRESS.");
        sender = _newSender;
    }

    function setAllocation(address token, address[] calldata recipients, uint256[] calldata rates) external onlyAdmin(){
        require(recipients.length == rates.length, "Error array data.");
        delete allocationInfo[token];
        Allocation storage a = allocationInfo[token];
        uint total;
        for(uint i=0; i<recipients.length; i++){
            require(recipients[i] != address(0), "ZERO_ADDRESS");
            require(rates[i] > 0, "ZERO_RATE");
            a.recipients.push(recipients[i]);
            a.rates.push(rates[i]);
            total += rates[i];
        }
        require(total == 1000, "INVALID_RATE");
    }

    function getQuoteAmount(
        address token0,
        address token1,
        uint256 amount0
    ) external view returns (uint256) {

        address factory = IUniswapV2Router02(uniswapV2Router).factory();
        address pair = IUniswapV2Factory(factory).getPair(token0, token1);

        // pair 不存在
        if (pair == address(0)) {
            return 0;
        }

        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();

        // 首次加池（无价格）
        if (r0 == 0 || r1 == 0) {
            return 0;
        }

        address t0 = IUniswapV2Pair(pair).token0();

        if (t0 == token0) {
            return IUniswapV2Router02(uniswapV2Router).quote(amount0, r0, r1);
        } else {
            return IUniswapV2Router02(uniswapV2Router).quote(amount0, r1, r0);
        }
    }


    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        string calldata remark
    ) external nonReentrant {

        require(amount0 > 0, "ZERO_AMOUNT");

        // 1. 计算配对数量（只允许已有池子）
        uint256 amount1 = this.getQuoteAmount(token0, token1, amount0);
        require(amount1 > 0, "PAIR_NOT_READY");

        // 2. 把 token 转入本合约
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        // 3. 授权 Router
        TransferHelper.safeApprove(token0, uniswapV2Router, amount0);
        TransferHelper.safeApprove(token1, uniswapV2Router, amount1);

        // 4. 加流动性（LP 接收地址 = 本合约）
        (uint amountA,uint amountB,uint liquidity) = IUniswapV2Router02(uniswapV2Router).addLiquidity(
            token0,
            token1,
            amount0,
            amount1,
            0,              // amountAMin
            0,              // amountBMin
            address(this),  // LP to this contract
            block.timestamp
        );

        address factory = IUniswapV2Router02(uniswapV2Router).factory();
        address pair = IUniswapV2Factory(factory).getPair(token0, token1);

        emit Liquidity(remark, msg.sender, token0, amountA, token1, amountB, pair, liquidity, Mark.ADD);
    }

    function removeLiquidity(
        address token0, 
        address token1,
        uint256 amount, 
        address to, 
        string calldata remark
    ) external onlyAdmin{
        (
            address pair,
            uint amountA,
            uint amountB
        ) = _removeLiquidityInternal(token0, token1, amount, to);

        emit Liquidity(
            remark,
            to,
            token0,
            amountA,
            token1,
            amountB,
            pair,
            amount,
            Mark.REMOVE
        );

    }

    function _removeLiquidityInternal(
        address token0,
        address token1,
        uint256 amount,
        address to
    ) internal returns (address pair, uint amountA, uint amountB) {
        address factory = IUniswapV2Router02(uniswapV2Router).factory();
        pair = IUniswapV2Factory(factory).getPair(token0, token1);
        require(pair != address(0), "Invalid pair.");

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        require(lpBalance >= amount, "Insufficient amount.");

        TransferHelper.safeApprove(pair, uniswapV2Router, amount);

        (amountA, amountB) = IUniswapV2Router02(uniswapV2Router).removeLiquidity(
            token0,
            token1,
            amount,
            0,
            0,
            to,
            block.timestamp + 30
        );
    }


    function swapExactIn(
        address fromToken, 
        address targetToken, 
        uint256 fromAmount, 
        address from, 
        address to,
        string calldata remark
    ) external onlyAdmin{
        address factory = IUniswapV2Router02(uniswapV2Router).factory();
        address pair = IUniswapV2Factory(factory).getPair(fromToken, targetToken);
        require(pair != address(0), "Invalid pair.");
        uint256 lpSupply = IERC20(pair).totalSupply();
        require(lpSupply > 0,"Liquidity does not exist.");
        TransferHelper.safeTransferFrom(fromToken, from, address(this), fromAmount);
        TransferHelper.safeApprove(fromToken, uniswapV2Router, fromAmount);
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = targetToken;
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            fromAmount, 
            0, 
            path, 
            to, 
            block.timestamp + 30
        );

        emit Exchange(remark, fromToken, fromAmount, targetToken, from, to);

    } 

    function multiRecharge(
        address token0, 
        address token1, 
        uint256 amount0, 
        uint256 amount1, 
        string calldata remark
    ) external nonReentrant {

        if (amount0 > 0) {
            _rechargeToken(token0, amount0);
        }

        if (amount1 > 0) {
            _rechargeToken(token1, amount1);
        }

        emit MultiRecharge(
            remark,
            msg.sender,
            token0,
            amount0,
            token1,
            amount1
        );
    }

    function _rechargeToken(address token, uint256 amount) internal {
        // 1. 拉 token
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

        Allocation storage a = allocationInfo[token];

        // 2. 没有分配规则 → 全部给 recipient
        if (a.recipients.length == 0) {
            TransferHelper.safeTransfer(token, recipient, amount);
            return;
        }

        // 3. 按 allocation 分配
        uint256 len = a.recipients.length;
        uint256 remaining = amount;

        for (uint256 i = 0; i < len; i++) {
            uint256 share;

            // 最后一个人兜底，避免精度损失
            if (i == len - 1) {
                share = remaining;
            } else {
                share = amount * a.rates[i] / 1000;
                remaining -= share;
            }

            if (share > 0) {
                TransferHelper.safeTransfer(token, a.recipients[i], share);
            }
        }
    }


    function withdraw(string memory remark, address token, uint256 amount, address to) external onlyAdmin(){
        require(amount > 0,"ERROR_AMOUNT.");
        if(token != address(0)) TransferHelper.safeTransferFrom(token, sender, to, amount);
        else TransferHelper.safeTransferETH(to, amount);
        emit Withdraw(remark, token, to, amount);
    }

    function multiBalanceOf(address token, address[] calldata users) external view returns (Info[] memory) {
        uint256 len = users.length;
        Info[] memory infos = new Info[](len);

        if (token == address(0)) {
            // 查询 ETH 余额
            for (uint256 i = 0; i < len; i++) {
                infos[i] = Info({
                    user: users[i],
                    amount: users[i].balance
                });
            }
        } else {
            // 查询 ERC20 余额
            IERC20 tokenContract = IERC20(token);
            for (uint256 i = 0; i < len; i++) {
                infos[i] = Info({
                    user: users[i],
                    amount: tokenContract.balanceOf(users[i])
                });
            }
        }

        return infos;
    }

    function getPrice(address token) external view returns(address, uint256) {
        address pairWBNB = IUniswapV2Factory(uniswapV2factory).getPair(token, WBNB);
        address pairUSDT = IUniswapV2Factory(uniswapV2factory).getPair(token, USDT);

        uint256 amountIn = 1e18; // 假设 token 有 18 位精度
        uint256 amountOut;

        // 优先返回 USDT 交易对
        if(pairUSDT != address(0)) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = USDT;
            uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2Router).getAmountsOut(amountIn, path);
            amountOut = amountsOut[amountsOut.length - 1]; 
            return (USDT, amountOut);
        }

        // 否则返回 WBNB 交易对
        if(pairWBNB != address(0)) {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WBNB;
            uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2Router).getAmountsOut(amountIn, path);
            amountOut = amountsOut[amountsOut.length - 1];
            return (WBNB, amountOut);
        }

        // 如果两个交易对都不存在，返回 0
        return (address(0), 0);
    }

    function getAllowance(address token, address owner) public view  returns (uint256){
        return IERC20(token).allowance(owner, address(this));
    }

}
