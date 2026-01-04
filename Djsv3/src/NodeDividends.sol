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
    address public USDT;
    address public nfts;
    address public token;
    address public staking;
    
    struct User{
        uint256   amountNFT;
        uint256   farmDebt;
        uint256   pending;
        uint256[] orderIds;
    }
    mapping(address => User) public userInfo;
    struct Order{
        address holder;
        uint256 nftQuantity;
        uint256[] tokenIds;
        uint256 tokenQuota;
        uint256 stakingTime;
        uint256 extracted;
    }
    mapping(uint256 => Order) orderInfo;

    uint256 public totalNftQuantity;
    uint256 public perNftAward;
    uint256 public forexRate;
    uint256 public totalDuration;
    uint256 public orderIndex;

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
        address _usdt,
        address _nfts,
        address _token
    ) public initializer {
        __Ownable_init(_msgSender());
        USDT = _usdt;
        nfts = _nfts;
        token = _token;
        forexRate = 500e18;
        totalDuration = 30 * 86400;
        orderIndex = 1;
    }

    function setStaking(address _staking) external onlyOwner{
        staking = _staking;
    }

    function setForexRate(uint256 _forexRate) external onlyOwner{
        forexRate = _forexRate;
    }

    function updateFarm(uint256 amountUSDT) external onlyFarm() {
        if (totalNftQuantity == 0) {
            return;
        }
        perNftAward += (amountUSDT / totalNftQuantity);
    }

    function stake(uint256[] calldata tokenIds) external {
        require(tokenIds.length > 0, "EMPTY");

        // ========== 先结算用户已有的 USDT ==========
        User storage u = userInfo[msg.sender];
        if (u.amountNFT > 0) {
            uint256 pending = u.amountNFT * perNftAward - u.farmDebt;
            if (pending > 0) {
                u.pending += pending;
            }
        }

        // ========== 创建 order ==========
        Order storage o = orderInfo[orderIndex];
        o.holder = msg.sender;
        o.nftQuantity = tokenIds.length;
        o.stakingTime = block.timestamp;
        o.tokenQuota = tokenIds.length * forexRate;

        for (uint i = 0; i < tokenIds.length; i++) {
            IERC721(nfts).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            o.tokenIds.push(tokenIds[i]);
        }

        // ========== 更新用户 & 全局 ==========
        u.amountNFT += tokenIds.length;
        u.orderIds.push(orderIndex);

        totalNftQuantity += tokenIds.length;

        // ⚠️ 关键：更新 farmDebt
        u.farmDebt = u.amountNFT * perNftAward;

        orderIndex++;
    }


    function getExtractable(uint256 orderId) public view returns(uint256){
        Order storage o = orderInfo[orderId];
        if (o.tokenQuota == 0 || o.stakingTime == 0) return 0;
        uint256 elapsed = block.timestamp - o.stakingTime;
        if (elapsed >= totalDuration) {
            return o.tokenQuota - o.extracted;
        } else {
            return (o.tokenQuota * elapsed) / totalDuration - o.extracted;
        }
    }

    function getCountdown(uint256 orderId) public view returns (uint256) {
        Order storage o = orderInfo[orderId];
        if (o.stakingTime == 0) return 0;

        uint256 elapsed = block.timestamp - o.stakingTime;
        if (elapsed >= totalDuration) return 0;
        else return totalDuration - elapsed;
    }

    function getOrderInfo(
        uint256 orderId
    ) external view returns (
        uint256 nftQuantity,
        uint256[] memory tokenIds,
        uint256 tokenQuota,
        uint256 stakingTime,
        uint256 extracted,
        uint256 extractable,
        uint256 countDown
    ) {
        Order storage o = orderInfo[orderId];

        nftQuantity = o.nftQuantity;
        tokenIds = o.tokenIds;
        tokenQuota = o.tokenQuota;
        stakingTime = o.stakingTime;
        extracted = o.extracted;

        extractable = getExtractable(orderId);
        countDown = getCountdown(orderId);
    }

    function claimOrderAward(uint256 orderId) external{
        require(orderInfo[orderId].holder == msg.sender, "Not permit.");
        uint256 award = 0;
        award = getExtractable(orderId);
        require(award > 0, "NO_AWARD");
        orderInfo[orderId].extracted += award;
        TransferHelper.safeTransfer(token, msg.sender, award);
    }

    function claimUserUSDT() external {
        User storage u = userInfo[msg.sender];

        uint256 pending = u.amountNFT * perNftAward - u.farmDebt;
        uint256 total = u.pending + pending;

        require(total > 0, "NO_REWARD");

        u.pending = 0;
        u.farmDebt = u.amountNFT * perNftAward;

        TransferHelper.safeTransfer(USDT, msg.sender, total);
    }

    function getAwardUsdt(address user) public view returns (uint256) {
        User storage u = userInfo[user];
        if (u.amountNFT == 0) return u.pending;

        uint256 pending = u.amountNFT * perNftAward - u.farmDebt;
        return u.pending + pending;
    }

    function getUserInfo(
        address user
    ) external view returns (
        uint256 amountNFT,
        uint256[] memory allOrders,
        // uint256[] memory pendingOrders,
        // uint256[] memory finishedOrders,
        uint256 awardUSDT
    ) {
        User storage u = userInfo[user];

        amountNFT = u.amountNFT;
        allOrders = u.orderIds;
        awardUSDT = getAwardUsdt(user);

    }

    function isOrderFinished(uint256 orderId) public view returns (bool) {
        return orderInfo[orderId].extracted >= orderInfo[orderId].tokenQuota;
    }

}