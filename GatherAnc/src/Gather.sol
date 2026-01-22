// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { ReentrancyGuard } from "./libraries/ReentrancyGuard.sol";

interface IVenus {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}


contract Gather is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard{
    event Staked(address user, uint256 amount);
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant VENUS = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    enum NodeType{INVALID, SMALL, LARGE}
    mapping(address => NodeType) public userInfo;
    mapping(NodeType => uint256) public nodePrice;

    address public recipient;

    struct Info{
        address user;
        NodeType nodeType;
    }
    Info[] infos;
    // Authorize contract upgrades only by the owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner(){}

    function initialize(address _recipient) public initializer {
        __Ownable_init(_msgSender());
        recipient = _recipient;
        nodePrice[NodeType.SMALL] = 300e18;
        nodePrice[NodeType.LARGE] = 1000e18;
    }


    function stake(NodeType nodeType) external nonReentrant(){
        require(userInfo[msg.sender] == NodeType.INVALID, "Already purchased.");
        require(nodePrice[nodeType] > 0, "Price error.");
        TransferHelper.safeTransferFrom(USDT, msg.sender, address(this), nodePrice[nodeType]);

        TransferHelper.safeApprove(USDT, VENUS, 0);
        TransferHelper.safeApprove(USDT, VENUS, nodePrice[nodeType]);
        require(IVenus(VENUS).mint(nodePrice[nodeType]) == 0, "Venus mint failed.");

        uint256 venusAmount = IERC20(VENUS).balanceOf(address(this));
        TransferHelper.safeTransfer(VENUS, recipient, venusAmount);


        userInfo[msg.sender] = nodeType;
        infos.push(Info({
            user:msg.sender,
            nodeType:nodeType
        }));

        emit Staked(msg.sender, nodePrice[nodeType]);
    }

    function getInfos() external view returns(Info[] memory){
        return infos;
    }
}