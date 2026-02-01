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

    enum UpdateType {STAKE, REDEEM}
    uint16[10] public levelPercents;

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

    EnumerableSet.AddressSet private tenThousandUSDTAddrSets;
    EnumerableSet.AddressSet private thirtyThousandUSDTAddrSets;

    mapping(address => mapping(address => uint256)) public linePerformance;
    mapping(address => address) public maxChild;
    mapping(address => uint256) public maxChildPerformance;

    uint256 public totalUsdtRankEffectivePerformance;
    uint256 public totalAncRankEffectivePerformance;

    FarmCore public farmCore;
    address public initialCode;

    uint256 private constant TEN_THOUSAND_USDT_RANK_THRESHOLD = 1e4 * 1e18;
    uint256 private constant THIRTY_THOUSAND_USDT_RANK_THRESHOLD  = 3e4 * 1e18;

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function initialize(address _initialCode) public initializer {
        __Ownable_init(_msgSender());
        initialCode = _initialCode;
        levelPercents = [
            800,300,50,50,50,50,50,50,50,50
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

    // ======================Admin Referral Registration ======================
    function referral(address recommender, address[] calldata users) external onlyCore{
        if (recommender != initialCode) {
            require(
                referralInfo[recommender].recommender != address(0),
                "RECOMMENDATION_IS_REQUIRED_REFERRAL"
            );
        }

        for(uint i=0; i<users.length; i++){
            if(users[i] != recommender && users[i] != initialCode){
                Referral storage r = referralInfo[users[i]];
                if(r.recommender == address(0)) r.recommender = recommender;
            }
        }
    }
    // ====================== Normal Referral Registration======================
    function referral(address recommender, address user) external onlyCore nonReentrant {
        require(user != initialCode, "Invalid sender");
        if (recommender == address(0)) recommender = initialCode;
        require(recommender != user, "Invalid recommender");

        // (,uint256 stakingUsdt,,,,) = farmCore.userInfo(recommender);
        // if (recommender != initialCode) {
        //     require(
        //         referralInfo[recommender].recommender != address(0) && stakingUsdt > 0,
        //         "RECOMMENDATION_IS_REQUIRED_REFERRAL"
        //     );
        // }
        require(referralInfo[user].recommender == address(0), "InviterExists");
        referralInfo[user].recommender = recommender;
    }

    // ====================== Stake / Redeem Processing ======================
    function processStakeReferralInfo(
        Process.NodeType nodeType,
        address user,
        uint256 amountLiquidity,
        uint256 amountUsdt
    ) external onlyCore {
        address current = referralInfo[user].recommender;
        uint8 level = 1;
        uint256 num = _handleDirectReferral(current, user);

        _updateEffectiveAndRank(user, amountLiquidity, UpdateType.STAKE);

        while (current != address(0) && level <= levelPercents.length) {
            Referral storage r = referralInfo[current];
            r.referralNum += num;
            r.overallPerformance += amountLiquidity;

            _updateEffectiveAndRank(current, amountLiquidity, UpdateType.STAKE);
            _tryIssueReferralReward(nodeType, current, user, level, amountUsdt);

            current = r.recommender;
            level++;
        }
    }

    function processRedeemReferralInfo(
        address user,
        uint256 stakingUsdt
    ) external onlyCore {
        address current = referralInfo[user].recommender;
        _updateEffectiveAndRank(user, stakingUsdt, UpdateType.REDEEM);
        uint8 level = 1;

        while (current != address(0) && level <= levelPercents.length) {
            Referral storage r = referralInfo[current];
            r.overallPerformance -= stakingUsdt;
            _updateEffectiveAndRank(current, stakingUsdt, UpdateType.REDEEM);
            current = r.recommender;
            level++;
        }
    }


    // ====================== Internal Helpers ======================
    function _handleDirectReferral(address parent, address user) internal returns (uint256 num) {
        if (!directReferralAddrSets[parent].contains(user)) {
            directReferralAddrSets[parent].add(user);
            return 1;
        }
        return 0;
    }


    function _tryIssueReferralReward(
        Process.NodeType nodeType,
        address current,
        address user,
        uint8 level,
        uint256 amountUsdt
    ) internal {
        if (nodeType != Process.NodeType.INVALID || amountUsdt == 0) return;

        uint256 directCount = directReferralAddrSets[current].length();
        uint8 maxLevel = directCount > 9 ? 10 : uint8(directCount);
        if (level > maxLevel) return;

        uint256 reward = amountUsdt * levelPercents[level - 1] / 10000;
        if (reward == 0) return;

        referralInfo[current].usdtReferralAward += reward;
        _recordAward(current, Process.Token.USDT_TOKEN, user, reward);
    }


    function _recordAward(
        address user,
        Process.Token token,
        address from,
        uint256 amount
    ) internal {
        awardRecords[user].push(
            Process.Record({
                token: token,
                from: from,
                amount: amount,
                time: block.timestamp
            })
        );
    }

    function _updateEffectiveAndRank(
        address user,
        uint256 amountLiquidity,
        UpdateType updateType
    ) internal {
        Referral storage r = referralInfo[user];
        uint256 oldEffective = r.effectivePerformance;
        address parent = r.recommender;

        // ===== 更新父子线业绩 =====
        if (parent != address(0)) {
            if (updateType == UpdateType.STAKE) {
                uint256 newVal = linePerformance[parent][user] + amountLiquidity;
                linePerformance[parent][user] = newVal;

                if (
                    newVal > maxChildPerformance[parent] ||
                    (newVal == maxChildPerformance[parent] && user < maxChild[parent])
                ) {
                    maxChildPerformance[parent] = newVal;
                    maxChild[parent] = user;
                }
            } else {
                linePerformance[parent][user] -= amountLiquidity;
                if (maxChild[parent] == user) {
                    _rebuildMaxChild(parent);
                }
            }
        }

        // ===== 更新 effectivePerformance =====
        uint256 maxVal = maxChildPerformance[user];
        r.effectivePerformance = r.overallPerformance > maxVal ? r.overallPerformance - maxVal : 0;

        // ===== 更新排行榜 =====
        _updateRank(user, oldEffective, r.effectivePerformance);
    }

    function _rebuildMaxChild(address parent) internal {
        address[] memory directs = directReferralAddrSets[parent].values();
        uint256 maxVal = 0;
        address maxAddr = address(0);

        for (uint256 i = 0; i < directs.length; i++) {
            address d = directs[i];
            uint256 v = linePerformance[parent][d];

            if (v > maxVal || (v == maxVal && d < maxAddr)) {
                maxVal = v;
                maxAddr = d;
            }
        }

        maxChildPerformance[parent] = maxVal;
        maxChild[parent] = maxAddr;
    }

    function _updateRank(
        address user,
        uint256 oldEffective,
        uint256 newEffective
    ) internal {
        bool wasTenThousand = tenThousandUSDTAddrSets.contains(user);
        bool wasThirtyThousand = thirtyThousandUSDTAddrSets.contains(user);

        // ===== USDT Rank =====
        if (wasTenThousand) {
            totalUsdtRankEffectivePerformance =
                totalUsdtRankEffectivePerformance + newEffective - oldEffective;

            if (newEffective < TEN_THOUSAND_USDT_RANK_THRESHOLD) {
                tenThousandUSDTAddrSets.remove(user);
                totalUsdtRankEffectivePerformance -= newEffective;
            }
        } else if (newEffective >= TEN_THOUSAND_USDT_RANK_THRESHOLD) {
            tenThousandUSDTAddrSets.add(user);
            totalUsdtRankEffectivePerformance += newEffective;
        }

        // ===== ANC Rank =====
        if (wasThirtyThousand) {
            totalAncRankEffectivePerformance =
                totalAncRankEffectivePerformance + newEffective - oldEffective;

            if (newEffective < THIRTY_THOUSAND_USDT_RANK_THRESHOLD) {
                thirtyThousandUSDTAddrSets.remove(user);
                totalAncRankEffectivePerformance -= newEffective;
            }
        } else if (newEffective >= THIRTY_THOUSAND_USDT_RANK_THRESHOLD) {
            thirtyThousandUSDTAddrSets.add(user);
            totalAncRankEffectivePerformance += newEffective;
        }
    }

    // ====================== Rank Award ======================
    function issueTenThousandUsdtRankAward(uint256 amount) external onlyCore {
        if (amount == 0 || totalUsdtRankEffectivePerformance == 0) return;
        address[] memory users = tenThousandUSDTAddrSets.values();
        uint256 len = users.length;

        for (uint256 i; i < len; i++) {
            Referral storage r = referralInfo[users[i]];
            if (r.effectivePerformance < TEN_THOUSAND_USDT_RANK_THRESHOLD) continue;

            uint256 reward = amount * r.effectivePerformance / totalUsdtRankEffectivePerformance;
            if (reward == 0) continue;

            r.usdtReferralAward += reward;
            _recordAward(users[i], Process.Token.USDT_TOKEN, address(0), reward);
        }
    }

    function issueThirtyThousandUsdtRankAward(Process.Token token, uint256 amount) external onlyCore {
        if (amount == 0 || totalAncRankEffectivePerformance == 0) return;
        address[] memory users = thirtyThousandUSDTAddrSets.values();
        uint256 len = users.length;

        for (uint256 i; i < len; i++) {
            Referral storage r = referralInfo[users[i]];
            if (r.effectivePerformance < THIRTY_THOUSAND_USDT_RANK_THRESHOLD) continue;

            uint256 reward = amount * r.effectivePerformance / totalAncRankEffectivePerformance;
            if (reward == 0) continue;

            if(token == Process.Token.ANC_TOKEN) r.ancReferralAward += reward;
            if(token == Process.Token.USDT_TOKEN) r.usdtReferralAward += reward;
            _recordAward(users[i], token, address(0), reward);
        }
    }

    // ====================== View / Getters ======================
    function getDirectReferralAddrs(address user) external view returns (address[] memory) {
        return directReferralAddrSets[user].values();
    }

    function getTenThousandRankAddrs() external view returns (address[] memory) {
        return tenThousandUSDTAddrSets.values();
    }

    function getThirtyThousandRankAddrs() external view returns (address[] memory) {
        return thirtyThousandUSDTAddrSets.values();
    }

    function getAwardRecords(address user) external view returns(Process.Record[] memory){
        return awardRecords[user];
    }
    
    function getBelongToRank(address user) external view returns(bool isTenRank, bool isThirtyRank){
        isTenRank = tenThousandUSDTAddrSets.contains(user);
        isThirtyRank = thirtyThousandUSDTAddrSets.contains(user);
    }
}