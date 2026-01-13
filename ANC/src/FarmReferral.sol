// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";
import { Process } from "./libraries/Process.sol";
import { FarmCore } from "./FarmCore.sol";

contract FarmReferral is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint16[20] public levelPercents;

    struct Referral {
        address recommender;
        uint256 usdtReferralAward;
        uint256 ancReferralAward;
        uint256 overallPerformance;
        uint256 effectivePerformance;
        uint256 referralNum;
    }

    mapping(address => Referral) public referralInfo;
    mapping(address => Process.Record[]) public awardRecords;
    mapping(address => EnumerableSet.AddressSet) private directReferralAddrSets;

    EnumerableSet.AddressSet private usdtRankAddrSets;
    EnumerableSet.AddressSet private ancRankAddrSets;

    mapping(address => mapping(address => uint256)) public linePerformance;
    mapping(address => address) public maxChild;

    uint256 public totalUsdtRankEffectivePerformance;
    uint256 public totalAncRankEffectivePerformance;

    FarmCore public farmCore;
    address public initialCode;

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function initialize(address _initialCode) public initializer {
        __Ownable_init(_msgSender());
        initialCode = _initialCode;
        levelPercents = [
            1000,500,200,80,80,80,80,80,80,20,
            20,20,20,20,20,20,20,20,20,20
        ];
    }

    modifier onlyCore() {
        require(msg.sender == address(farmCore), "Not permit");
        _;
    }

    function setFarmCore(FarmCore _farmCore) external onlyOwner {
        farmCore = _farmCore;
    }

    function getRecommender(address user) external view returns (address) {
        return referralInfo[user].recommender;
    }

    function referral(address recommender, address user) external onlyCore nonReentrant {
        require(user != initialCode, "Invalid sender");

        if (recommender == address(0)) recommender = initialCode;
        require(recommender != user, "Invalid recommender");

        (,uint256 stakingUsdt,,,,) = farmCore.userInfo(recommender);
        if (recommender != initialCode) {
            require(
                referralInfo[recommender].recommender != address(0) && stakingUsdt > 0,
                "RECOMMENDATION_IS_REQUIRED_REFERRAL"
            );
        }

        require(referralInfo[user].recommender == address(0), "InviterExists");
        referralInfo[user].recommender = recommender;
    }

    function processStakeReferralInfo(
        address user,
        uint256 amountLiquidity,
        uint256 amountUsdt
    ) external onlyCore {
        address current = referralInfo[user].recommender;
        uint8 level = 1;
        uint256 num = 0;

        if (!directReferralAddrSets[current].contains(user)) {
            directReferralAddrSets[current].add(user);
            num = 1;
        }

        while (current != address(0) && level <= 20) {
            Referral storage r = referralInfo[current];

            r.referralNum += num;
            r.overallPerformance += amountLiquidity;
            linePerformance[current][user] += amountLiquidity;

            _updateEffectiveAndRank(current);

            uint256 directCount = directReferralAddrSets[current].length();
            uint8 maxLevel = directCount > 9 ? 20 : uint8(directCount);

            if (level <= maxLevel && amountUsdt > 0) {
                uint256 reward = amountUsdt * levelPercents[level - 1] / 10000;
                if (reward > 0) {
                    r.usdtReferralAward += reward;
                    awardRecords[current].push(
                        Process.Record({
                            token: Process.Token.USDT_TOKEN,
                            from: user,
                            amount: reward,
                            time: block.timestamp
                        })
                    );
                }
            }

            current = r.recommender;
            level++;
        }
    }

    function processRedeemReferralInfo(
        address user,
        uint256 stakingUsdt
    ) external onlyCore {
        address current = referralInfo[user].recommender;
        uint8 level = 1;

        while (current != address(0) && level <= 20) {
            Referral storage r = referralInfo[current];

            r.overallPerformance =
                r.overallPerformance >= stakingUsdt
                    ? r.overallPerformance - stakingUsdt
                    : 0;

            linePerformance[current][user] =
                linePerformance[current][user] >= stakingUsdt
                    ? linePerformance[current][user] - stakingUsdt
                    : 0;

            _updateEffectiveAndRank(current);

            current = r.recommender;
            level++;
        }
    }

    function _updateEffectiveAndRank(address user) internal {
        Referral storage r = referralInfo[user];
        uint256 oldEffective = r.effectivePerformance;

        address[] memory directs = directReferralAddrSets[user].values();
        uint256 total;
        uint256 maxValue;
        address maxAddr;

        for (uint256 i = 0; i < directs.length; i++) {
            uint256 v = linePerformance[user][directs[i]];
            total += v;
            if (v > maxValue || (v == maxValue && directs[i] < maxAddr)) {
                maxValue = v;
                maxAddr = directs[i];
            }
        }

        maxChild[user] = maxAddr;

        uint256 newEffective = total > maxValue ? total - maxValue : 0;
        r.effectivePerformance = newEffective;

        bool wasUsdt = usdtRankAddrSets.contains(user);
        bool wasAnc = ancRankAddrSets.contains(user);

        // ===== USDT Rank =====
        if (wasUsdt) {
            // 先假设仍在榜内，做 delta
            totalUsdtRankEffectivePerformance =
                totalUsdtRankEffectivePerformance + newEffective - oldEffective;

            // 若跌破门槛，再整体移除（回滚 delta，改为 -old）
            if (newEffective < 2e4 * 1e18) {
                usdtRankAddrSets.remove(user);
                totalUsdtRankEffectivePerformance -= newEffective;
            }
        } else {
            // 原本不在榜
            if (newEffective >= 2e4 * 1e18) {
                usdtRankAddrSets.add(user);
                totalUsdtRankEffectivePerformance += newEffective;
            }
        }

        // ===== ANC Rank（同理）=====
        if (wasAnc) {
            totalAncRankEffectivePerformance =
                totalAncRankEffectivePerformance + newEffective - oldEffective;

            if (newEffective < 5e4 * 1e18) {
                ancRankAddrSets.remove(user);
                totalAncRankEffectivePerformance -= newEffective;
            }
        } else {
            if (newEffective >= 5e4 * 1e18) {
                ancRankAddrSets.add(user);
                totalAncRankEffectivePerformance += newEffective;
            }
        }
    }


    function issueUsdtAwardForRank(uint256 amount) external onlyCore {
        if (amount == 0 || totalUsdtRankEffectivePerformance == 0) return;

        address[] memory users = usdtRankAddrSets.values();
        for (uint256 i = 0; i < users.length; i++) {
            Referral storage r = referralInfo[users[i]];
            if (r.effectivePerformance == 0) continue;

            uint256 reward =
                amount * r.effectivePerformance / totalUsdtRankEffectivePerformance;

            if (reward == 0) continue;

            r.usdtReferralAward += reward;
            awardRecords[users[i]].push(
                Process.Record({
                    token: Process.Token.USDT_TOKEN,
                    from: address(0),
                    amount: reward,
                    time: block.timestamp
                })
            );
        }
    }

    function issueAncAwardForRank(uint256 amount) external onlyCore {
        if (amount == 0 || totalAncRankEffectivePerformance == 0) return;

        address[] memory users = ancRankAddrSets.values();
        for (uint256 i = 0; i < users.length; i++) {
            Referral storage r = referralInfo[users[i]];
            if (r.effectivePerformance < 5e4 * 1e18) continue;

            uint256 reward =
                amount * r.effectivePerformance / totalAncRankEffectivePerformance;

            if (reward == 0) continue;

            r.ancReferralAward += reward;
            awardRecords[users[i]].push(
                Process.Record({
                    token: Process.Token.ANC_TOKEN,
                    from: address(0),
                    amount: reward,
                    time: block.timestamp
                })
            );
        }
    }

    function getDirectReferralAddrs(address user) external view returns (address[] memory) {
        return directReferralAddrSets[user].values();
    }

    function getUsdtRankAddrs() external view returns (address[] memory) {
        return usdtRankAddrSets.values();
    }

    function getAncRankAddrs() external view returns (address[] memory) {
        return ancRankAddrSets.values();
    }
}

