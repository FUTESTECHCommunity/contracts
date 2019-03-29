pragma solidity ^0.4.25;

contract LockRequestable {
    uint256 public lockRequestCount;
    
    constructor() public {
        lockRequestCount = 0;
    }
    
    function generateLockId() internal returns(bytes32) {
        return keccak256(abi.encodePacked(block.number-1, address(this), ++lockRequestCount));
    }
}