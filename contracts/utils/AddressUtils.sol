// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library AddressUtils {
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {size := extcodesize(addr)}
        return size > 0;
    }
}
