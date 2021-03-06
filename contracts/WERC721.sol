// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WERC721 is Ownable, ERC721 {
    using SafeMath for uint256;

    mapping(address => bool) private eligibleUsers;
    mapping(uint256 => string) public tokensData;

    uint256 public totalSupply;

    constructor (address[] memory _eligibleUsers, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        eligibleUsers[msg.sender] = true;
        for (uint256 i = 0; i < _eligibleUsers.length; i++) {
            eligibleUsers[_eligibleUsers[i]] = true;
        }
    }

    function mint(address _to, string memory _data) public onlyEligibleUser(msg.sender) {
        uint256 _tokenId = totalSupply.add(1);
        totalSupply = _tokenId;
        tokensData[_tokenId] = _data;
        _safeMint(_to, _tokenId);
    }

    function tokensOfOwner(address _ownerOfTokens) public view returns (uint256[] memory) {
        uint256 _tokenCount = balanceOf(_ownerOfTokens);

        if (_tokenCount == 0) {
            return new uint256[](0);
        }

        uint256[] memory _ownerTokens = new uint256[](_tokenCount);
        uint256 _totalSupply = totalSupply;
        uint256 _resultIndex = 0;

        for (uint256 _tokenId = 1; _tokenId <= _totalSupply; _tokenId++) {
            if (ownerOf(_tokenId) == _ownerOfTokens) {
                _ownerTokens[_resultIndex] = _tokenId;
                _resultIndex++;
            }
        }

        return _ownerTokens;
    }

    function switchUserPermissions(address _user) public onlyOwner {
        eligibleUsers[_user] = !eligibleUsers[_user];
    }

    modifier onlyEligibleUser(address _user) {
        require(eligibleUsers[_user], "Is not eligible user");
        _;
    }
}
