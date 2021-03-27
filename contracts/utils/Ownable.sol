// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

abstract contract Ownable {
    address private owner;

    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    constructor () {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function getOwner() public view virtual returns (address) {
        return owner;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function transferOwnership(address _newOwner) public virtual onlyOwner {
        require(_newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
