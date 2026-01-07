// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";


contract Finance is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    event Referral(address recommender, address user);
    event Stake(address user, uint256 amount);

    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public initialCode;
    address public recipient;
    enum Category{INVALID, ENVOY, DIRECTOR, SHARE}
    mapping(Category => uint256) public price;
    struct User{
        Category category;
        address  recommender;
        uint256  amount;
        uint256  performance;
    }
    mapping(address => User) public userInfo;
    mapping(address => address[]) directReferrals;
    mapping(address => bool) isAddDirectReferrals;
    mapping(Category => address[]) nodeAddrs;
    mapping(address => mapping(Category => uint256)) nodeNums;

    uint256 public totalUsdtAmount;

    uint256[50] private __gap;
    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(
        address _initialCode,
        address _recipient
    ) public initializer {
        __Ownable_init(_msgSender());
        initialCode = _initialCode;
        recipient = _recipient;
        price[Category.ENVOY] = 500e18;
        price[Category.DIRECTOR] = 1000e18;
        price[Category.SHARE] = 3000e18;
    }

    function setPrice(uint256 _envoy, uint256 _director, uint256 _share) external onlyOwner{
        price[Category.ENVOY] = _envoy;
        price[Category.DIRECTOR] = _director;
        price[Category.SHARE] = _share;
    }


    function referral(address _recommender) external nonReentrant {
        require(initialCode != msg.sender);

        if (_recommender == address(0)) {
            _recommender = initialCode;
        }

        if (_recommender != initialCode) {
            require(
                userInfo[_recommender].category != Category.INVALID,
                "Not referral permit."
            );
        }

        require(
            userInfo[msg.sender].recommender == address(0),
            "The inviter has already been linked."
        );


        userInfo[msg.sender].recommender = _recommender;
        emit Referral(_recommender, msg.sender);
    }


    function validInvitationCode(address addr) external view returns(bool){
        if(addr == initialCode || addr == address(0)) return true;
        return userInfo[addr].category != Category.INVALID;
    }


    function stake(Category category) external nonReentrant{
        require(price[category] > 0,"Invalid category.");

        User storage u = userInfo[msg.sender];
        require(initialCode != msg.sender);
        require(u.recommender != address(0), "Not required referral.");
        require(u.category == Category.INVALID, "Already purchased.");
        TransferHelper.safeTransferFrom(USDT, msg.sender, recipient, price[category]);
        u.amount = price[category];
        u.category = category;
        totalUsdtAmount += price[category];
        nodeAddrs[category].push(msg.sender);
        if(!isAddDirectReferrals[msg.sender]) {
            directReferrals[u.recommender].push(msg.sender);
            isAddDirectReferrals[msg.sender] = true;
        }

        _processReferralNumber(msg.sender, category);
        _processReferralPerformance(msg.sender, price[category]);
        emit Stake(msg.sender, price[category]);
    }

    function _processReferralPerformance(address user, uint256 amountUSDT) private{
        
        address current = userInfo[user].recommender;

        while (current != address(0)) {
            if (current == user) {
                break;
            }
            userInfo[current].performance += amountUSDT;
            current = userInfo[current].recommender;
        }
    }

    function _processReferralNumber(address user, Category category) private{
        address current = userInfo[user].recommender;
        while (current != address(0) ) {
            if (current == user) {
                break;
            }
            // userInfo[current].referralNum += 1;
            nodeNums[current][category] += 1;
            current = userInfo[current].recommender;
        }
    }

    function getUserInfo(address user) external view 
        returns(
            Category category,
            address  recommender,
            uint256  amount,
            uint256  performance,
            uint256  envoyNums,
            uint256  directorNums,
            uint256  shareNums
        )
    {
        User memory u = userInfo[user];
        category = u.category;
        recommender = u.recommender;
        amount = u.amount;
        performance = u.performance;
        envoyNums = nodeNums[user][Category.ENVOY];
        directorNums = nodeNums[user][Category.DIRECTOR];
        shareNums = nodeNums[user][Category.SHARE];
    }

    function getCategoryAddrs(Category category) external view returns(address[] memory){
        return nodeAddrs[category];
    }

    struct DirectReferralsInfo{
        Category category;
        address referral;
        uint256 performance;
    }

    function getDirectReferralsInfo(address user) 
        external 
        view 
        returns (DirectReferralsInfo[] memory) 
    {
        address[] memory referrals = directReferrals[user];
        uint256 len = referrals.length;

        DirectReferralsInfo[] memory infoList = new DirectReferralsInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            address ref = referrals[i];
            infoList[i] = DirectReferralsInfo({
                category: userInfo[ref].category,
                referral: ref,
                performance: userInfo[ref].performance
            });
        }

        return infoList;
    }
}