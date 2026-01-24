// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";
import { FarmCore } from "./FarmCore.sol";
import { Process } from "./libraries/Process.sol";

contract FarmToday is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) public usdtTodayAward;
    mapping(address => Process.Record[]) public awardRecords;
    mapping(uint256 => EnumerableSet.AddressSet) private todayDirectAddrSets;
    mapping(address => mapping(uint256 => uint256)) public todayDirectPerformance;
    uint256 public todayRounds;


    FarmCore farmCore;

    modifier onlyCore() {
        require(address(farmCore) == msg.sender, "Not permit.");
        _;
    } 

    function setFarmCore(FarmCore _farmCore) external onlyOwner(){
        farmCore = _farmCore;
    }  

    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize() public initializer {
        __Ownable_init(_msgSender());
    }

    function processTodayTopInfo(address inviter, uint256 amountToLiquidity) external onlyCore{
        if(!todayDirectAddrSets[todayRounds].contains(inviter)){
            todayDirectAddrSets[todayRounds].add(inviter);
        }

        todayDirectPerformance[inviter][todayRounds] += amountToLiquidity;      
    }

    function issueTodayTopAward(uint256 amount) external onlyCore {
        address[] memory addrs = todayDirectAddrSets[todayRounds].values();
        uint256 totalAddrs = addrs.length;

        // 没有人或者发奖金额为0，直接结束
        if (totalAddrs == 0 || amount == 0) {
            todayRounds++;
            return;
        }

        // 如果人数 <= 6，直接按顺序发奖
        if (totalAddrs <= 6) {
            uint256 totalPerformance = 0;
            for (uint256 i = 0; i < totalAddrs; i++) {
                totalPerformance += todayDirectPerformance[addrs[i]][todayRounds];
            }
            if (totalPerformance == 0) {
                todayRounds++;
                return;
            }

            for (uint256 i = 0; i < totalAddrs; i++) {
                uint256 perf = todayDirectPerformance[addrs[i]][todayRounds];
                uint256 reward = (amount * perf) / totalPerformance;
                if (reward > 0) {
                    usdtTodayAward[addrs[i]] += reward;
                    // awardRecords[addrs[i]].push(Process.Record{})
                    awardRecords[addrs[i]].push(Process.Record({
                        token: Process.Token.USDT_TOKEN, 
                        from: address(this), 
                        amount: reward, 
                        time: block.timestamp
                    }));
                }
            }
            todayRounds++;
            return;
        }

        // 如果人数 > 6，才需要排序找 top 6
        uint256 topCount = 6;
        address[] memory topAddrs = new address[](topCount);
        uint256[] memory topPerformances = new uint256[](topCount);

        for (uint256 i = 0; i < totalAddrs; i++) {
            address u = addrs[i];
            uint256 perf = todayDirectPerformance[u][todayRounds];

            // 尝试插入 topPerformances
            for (uint256 j = 0; j < topCount; j++) {
                if (perf > topPerformances[j] || (perf == topPerformances[j] && u < topAddrs[j])) {
                    for (uint256 k = topCount - 1; k > j; k--) {
                        topPerformances[k] = topPerformances[k - 1];
                        topAddrs[k] = topAddrs[k - 1];
                    }
                    topPerformances[j] = perf;
                    topAddrs[j] = u;
                    break;
                }
            }
        }

        // 计算 topTotalPerformance
        uint256 topTotalPerformance = 0;
        for (uint256 i = 0; i < topCount; i++) {
            topTotalPerformance += topPerformances[i];
        }

        if (topTotalPerformance > 0) {
            for (uint256 i = 0; i < topCount; i++) {
                uint256 reward = (amount * topPerformances[i]) / topTotalPerformance;
                if (reward > 0) {
                    usdtTodayAward[topAddrs[i]] += reward;
                    awardRecords[topAddrs[i]].push(Process.Record({
                        token: Process.Token.USDT_TOKEN, 
                        from: address(this), 
                        amount: reward, 
                        time: block.timestamp
                    }));
                }
            }
        }

        todayRounds++;
    }

    function getAwardRecords(address user) external view returns(Process.Record[] memory){
        return awardRecords[user];
    }

    function getTodayTopInfo() external view returns(Process.Today[] memory infos){
        address[] memory addrs = todayDirectAddrSets[todayRounds].values();
        uint256 totalAddrs = addrs.length;

        uint256 topCount = totalAddrs < 10 ? totalAddrs : 10;
        infos = new Process.Today[](topCount);

        // 临时数组存储 top 用户和业绩
        address[] memory topAddrs = new address[](topCount);
        uint256[] memory topPerformances = new uint256[](topCount);

        for (uint256 i = 0; i < totalAddrs; i++) {
            address u = addrs[i];
            uint256 perf = todayDirectPerformance[u][todayRounds];

            // 尝试插入 topPerformances
            for (uint256 j = 0; j < topCount; j++) {
                if (perf > topPerformances[j] || (perf == topPerformances[j] && u < topAddrs[j])) {
                    // 向后移动
                    for (uint256 k = topCount - 1; k > j; k--) {
                        topPerformances[k] = topPerformances[k - 1];
                        topAddrs[k] = topAddrs[k - 1];
                    }
                    topPerformances[j] = perf;
                    topAddrs[j] = u;
                    break;
                }
            }
        }

        // 填充 infos
        for (uint256 i = 0; i < topCount; i++) {
            infos[i] = Process.Today({
                user: topAddrs[i],
                performance: topPerformances[i]
            });
        }
    }


}