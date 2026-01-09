// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    error OwnableUnauthorizedAccount(address account);

    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}



library TransferHelper {
    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }
}

contract MultiTransfer is Ownable{
    address public x101v1;

    constructor(address _x101v1)Ownable(msg.sender){
        x101v1 = _x101v1;
    }

    function setX101v1Addr(address _x101v1) external onlyOwner(){
        x101v1 = _x101v1;
    }

    function multiTransfer(address token, address[] calldata ads) external onlyOwner(){
        require(token != address(0) && x101v1 != address(0), "ZERO_ADDR");
        for(uint i=0; i<ads.length; i++){
            uint256 x101v1Amount = IERC20(x101v1).balanceOf(ads[i]);
            if(x101v1Amount > 0) TransferHelper.safeTransfer(token, ads[i], x101v1Amount);
        }
    }

    function emergencyWithdraw(address token, address to) external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransfer(token, to, amount);
    }

}