// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";
import { Process } from "./libraries/Process.sol";
import { FarmCore } from "./FarmCore.sol";


contract FarmNode is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(Process.NodeType => EnumerableSet.AddressSet) private nodeAddsSets;
    mapping(address => uint256) public usdtNodeAward;
    mapping(address => Process.Record[]) public awardRecords;

    // Authorize contract upgrades only by the owner
    FarmCore farmCore;

    modifier onlyCore() {
        require(address(farmCore) == msg.sender, "Not permit.");
        _;
    } 

    function setFarmCore(FarmCore _farmCore) external onlyOwner(){
        farmCore = _farmCore;
    }  

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize() public initializer {
        __Ownable_init(_msgSender());
    }

    function addToNodeAddr(Process.NodeType nodeType, address nodeAddr) external onlyCore{
        if(!nodeAddsSets[nodeType].contains(nodeAddr)) nodeAddsSets[nodeType].add(nodeAddr);
    }

    function removeToNodeAddr(Process.NodeType nodeType, address nodeAddr) external onlyCore{
        if(nodeAddsSets[nodeType].contains(nodeAddr)) nodeAddsSets[nodeType].remove(nodeAddr);
    }

    function issueNodeAward(Process.NodeType[] memory nodeTypes, uint256[] memory amountUsdts) external onlyCore {
        require(nodeTypes.length == amountUsdts.length, "length mismatch");

        for (uint256 i = 0; i < nodeTypes.length; i++) {
            Process.NodeType nodeType = nodeTypes[i];
            uint256 totalAmount = amountUsdts[i];

            EnumerableSet.AddressSet storage addrs = nodeAddsSets[nodeType];
            uint256 count = addrs.length();
            if (count == 0 || totalAmount == 0) continue; // 没有地址或者奖励为0，跳过

            uint256 perAddr = totalAmount / count; // 平均分配
            for (uint256 j = 0; j < count; j++) {
                address addr = addrs.at(j);
                usdtNodeAward[addr] += perAddr;
                awardRecords[addr].push(Process.Record({
                    token: Process.Token.USDT_TOKEN,
                    from: address(0),
                    amount: perAddr,
                    time: block.timestamp
                }));
            }
        }
    }

    function getAwardRecords(address user) external view returns(Process.Record[] memory){
        return awardRecords[user];
    }

    function getNodeAddrs(Process.NodeType nodeType) external view returns(address[] memory){
        return nodeAddsSets[nodeType].values();
    }
}