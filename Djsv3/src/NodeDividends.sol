// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract NodeDividends is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC721Holder{
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public nfts;
    address public staking;
    address public token;
    
    struct User{
        uint256   nftQuantity;
        uint256[] tokenIds;
        uint256   releaseQuota;
        uint256   stakingTime;
        uint256   pendingToken;
        uint256   pendingUSDT;
        uint256   extractedToken;
        uint256   farmDebt;
    }


    mapping(address => User) public userInfo;
    uint256 public totalNftQuantity;
    uint256 public perNftAward;
    uint256 public forexRate;
    uint256 public totalDuration;

    receive() external payable {
        revert("NO_DIRECT_SEND");
    }

    modifier onlyFarm() {
        require(msg.sender == staking || msg.sender == token, "Not permit.");
        _;
    }

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(
        address _nfts,
        address _token
    ) public initializer {
        __Ownable_init(_msgSender());
        nfts = _nfts;
        token = _token;
        forexRate = 500e18;
        totalDuration = 30 * 86400;
    }

    function setStaking(address _staking) external onlyOwner{
        staking = _staking;
    }

    function updateFarm(uint256 amountUSDT) external onlyFarm() {

        // 如果没有 NFT 则不更新（或把钱保留至合约，取决于业务）
        if (totalNftQuantity == 0) {
            // 如果想把该笔资金记入某个池子，请实现额外逻辑
            return;
        }

        // 每个 NFT 增加的份额；注意：整除会丢失精度，建议用带小数位的单位（USDT 18 decimals）
        perNftAward += (amountUSDT / totalNftQuantity);
    }
    
    function stake(uint256[] memory tokenIds) external {
        User storage u = userInfo[msg.sender];
        if(u.releaseQuota > 0){
            (, uint256 claimable) = getReleaseAmountToken(msg.sender);
            if(claimable > 0) u.pendingToken = claimable;
        }
        

        for(uint i=0; i<tokenIds.length; i++){
            IERC721(nfts).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            u.tokenIds.push(tokenIds[i]);
        }
        u.pendingUSDT = getAvailableAmountUSDT(msg.sender);
        u.nftQuantity += tokenIds.length;
        u.releaseQuota += (tokenIds.length * forexRate);
        u.stakingTime = block.timestamp;
        u.farmDebt = u.nftQuantity * perNftAward;
        totalNftQuantity += tokenIds.length;

    }

    function getReleaseAmountToken(address user)
        public
        view
        returns (uint256 released, uint256 claimable)
    {
        User storage u = userInfo[user];

        // 如果没有 releaseQuota 或未开始释放
        if (u.releaseQuota == 0 && u.pendingToken == 0) {
            return (0, 0);
        }

        // currentReleased: 本周期基于 u.releaseQuota 从 stakingTime 到 now 已释放多少
        uint256 currentReleased = 0;
        if (u.stakingTime > 0 && u.releaseQuota > 0) {
            uint256 elapsed = block.timestamp - u.stakingTime;
            if (elapsed >= totalDuration) {
                currentReleased = u.releaseQuota;
            } else {
                currentReleased = (u.releaseQuota * elapsed) / totalDuration;
            }
        }

        // released = 历史 pending + 本周期已释放
        released = u.pendingToken + currentReleased;

        // claimable = released - 已真正发出的 (extractedToken)
        if (released <= u.extractedToken) {
            claimable = 0;
        } else {
            claimable = released - u.extractedToken;
        }
    }

    function getAvailableAmountUSDT(address user) public view returns(uint256){
        User storage u = userInfo[user];

        // totalEarned = pendingUSDT + nftQuantity * perNftAward
        uint256 totalEarned = u.pendingUSDT + (u.nftQuantity * perNftAward);

        // 如果 farmDebt >= totalEarned 返回 0，避免 underflow
        if (u.farmDebt >= totalEarned) return 0;
        return totalEarned - u.farmDebt;
    }

    function claimToken(uint256 amountToken) external {
        User storage u = userInfo[msg.sender];

        (, uint256 claimable) = getReleaseAmountToken(msg.sender);
        require(amountToken > 0 && amountToken <= claimable, "Invalid amount");

        // 优先从 pendingToken 减（如果 pending 不够则 pending=0，剩余由后续的线性释放抵扣）
        if (amountToken <= u.pendingToken) {
            u.pendingToken -= amountToken;
        } else {
            // 领走全部 pending，并剩余一部分从 future 的 released 中扣除
            u.pendingToken = 0;
            // 左边的 left 会通过增加 extractedToken 来代表已实际领取（getReleaseAmountToken 会用 extractedToken 抵扣）
            // 这里不需要额外修改 releaseQuota，因为 releaseQuota 的 "已释放" 部分已在 stake 时被扣除
            // 直接继续
        }

        // 真正转账给用户
        TransferHelper.safeTransfer(token, msg.sender, amountToken);

        // 标记为已真实发放
        u.extractedToken += amountToken;
    }

    function claimUSDT() external {
        User storage u = userInfo[msg.sender];

        uint256 amountUSDT = getAvailableAmountUSDT(msg.sender);
        require(amountUSDT > 0, "No USDT available");

        // 转账
        TransferHelper.safeTransfer(USDT, msg.sender, amountUSDT);

        // 将已结算到 now 的 USDT 清零（我们使用 pendingUSDT 来记录历史）
        // 这里我们已把当前可领的都发给用户，因此 pendingUSDT = 0
        u.pendingUSDT = 0;

        // 更新 farmDebt 把当前基线拉到最新：nftQuantity * perNftAward
        u.farmDebt = u.nftQuantity * perNftAward;
    }

    function getUserInfo(address user) 
        external 
        view 
        returns (
            uint256 nftQuantity,
            uint256[] memory tokenIds,
            uint256 releaseQuota,
            uint256 stakingTime,
            uint256 pendingToken,
            uint256 pendingUSDT,
            uint256 extractedToken,
            uint256 farmDebt,
            uint256 claimableToken,
            uint256 availableUSDT
        ) 
    {
        User storage u = userInfo[user];
        nftQuantity = u.nftQuantity;
        tokenIds = u.tokenIds;
        releaseQuota = u.releaseQuota;
        stakingTime = u.stakingTime;
        pendingToken = u.pendingToken;
        pendingUSDT = u.pendingUSDT;
        extractedToken = u.extractedToken;
        farmDebt = u.farmDebt;

        // 计算当前可领取
        (, claimableToken) = getReleaseAmountToken(user);
        availableUSDT = getAvailableAmountUSDT(user);
    }

    function emergencyWithdraw(address _token, uint256 _amount, address _to) external onlyOwner {
        TransferHelper.safeTransfer(_token, _to, _amount);
    }


}