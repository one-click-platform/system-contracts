// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WETH is Ownable, ERC20 {
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address _recepient, uint256 _amount) external onlyOwner returns (bool) {
        _mint(_recepient, _amount);
        return true;
    }
}
