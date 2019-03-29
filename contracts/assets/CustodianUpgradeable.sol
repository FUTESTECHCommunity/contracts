pragma solidity ^0.4.25;

import './LockRequestable.sol';

contract CustodianUpgradeable is LockRequestable {
    struct CustodianChangeRequest {
        address proposedNew;
    }
    event CustodianChangeRequested(
        bytes32 indexed lockId,
        address msgSender,
        address proposedCustodian
    );
    event CustodianChangeConfirmed(bytes32 indexed lockId, address newCustodian);
    
    address public custodian;
    mapping(bytes32 => CustodianChangeRequest) public custodianChangeReqs;
    mapping(bytes32 => mapping(address => uint256)) public guarantees;
    mapping(bytes32 => address) public requesters;
    
    constructor(address _custodian) public{
        custodian = _custodian;
    }
    
    modifier onlyCustodian() {
        require(msg.sender == custodian);
        _;
    }
    
    function requestCustodianChange(address _proposedCustodian) public payable returns(bytes32 lockId) {
        require(msg.value >= 1 ether);
        
        require(_proposedCustodian != address(0));

        lockId = generateLockId();
        custodianChangeReqs[lockId] = CustodianChangeRequest({
            proposedNew: _proposedCustodian
        });
        guarantees[lockId][msg.sender] = msg.value;
        requesters[lockId] = msg.sender;
        emit CustodianChangeRequested(lockId, msg.sender, _proposedCustodian);
    }
    
    function confirmCustodianChange(bytes32 _lockId) public onlyCustodian {
        custodian = getCustodianChangeReq(_lockId);
        
        delete custodianChangeReqs[_lockId];
        if (address(this).balance > 0) {
            uint256 balance = address(this).balance;
            address requester = requesters[_lockId];
            if(balance > guarantees[_lockId][requester]) {
                balance = guarantees[_lockId][requester];
            }
            requesters[_lockId].transfer(balance);
            // requesters[_lockId].send(balance);
        }
        emit CustodianChangeConfirmed(_lockId, custodian);
    }
    
    function getCustodianChangeReq(bytes32 lockId) private view returns (address) {
        CustodianChangeRequest memory instance = custodianChangeReqs[lockId];
        require(instance.proposedNew != address(0));
        return instance.proposedNew;
    }
    
}