// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WERC721 is Ownable, ERC721 {
    mapping(address => bool) private eligibleUsers;

    constructor (address[] memory _eligibleUsers, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        for (uint256 i = 0; i < _eligibleUsers.length; i++) {
            eligibleUsers[_eligibleUsers[i]] = true;
        }
    }

    function mint(address _to, uint256 _tokenId) public onlyEligibleUser(msg.sender) {
        _safeMint(_to, _tokenId);
    }

    function switchUserPermissions(address _user) public onlyOwner {
        eligibleUsers[_user] = !eligibleUsers[_user];
    }

    modifier onlyEligibleUser(address _user) {
        require(
            eligibleUsers[_user], "Is not eligible user"
        );
        _;
    }
}
