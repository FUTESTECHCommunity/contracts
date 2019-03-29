pragma solidity ^0.4.25;

import './library/access/roles/SignerRole.sol';
import './MultiSigFun.sol';

contract Requirement is SignerRole {
    event RequirementChange(uint required);
    uint private _required;
    uint private _signerCount;
    
    MSFun.Data private _msData;
    
    /*
     *  Constants
     */
    uint constant public MAX_OWNER_COUNT = 50;
    
    constructor(uint required) internal {
        // _addSigner(msg.sender); //repeat must be removed!
        _signerCount = 1;
        _required = required;
    }
    
    function _multiSig(bytes32 whatFunction) internal returns (bool) {
        return(MSFun.multiSig(_msData, _required, whatFunction));
    }
    
    function _deleteProposal(bytes32 whatFunction) internal {
        MSFun.deleteProposal(_msData, whatFunction);
    }
    
    function changeRequirement(uint required) public onlySigner {
        require(required != 0 && required <= _signerCount);
        if(_multiSig("changeRequirement") == true) {
            _deleteProposal("changeRequirement");
            
            _required = required;
            emit RequirementChange(_required);
        }
    }
    
    function getRequirement() public view returns(uint) {
        return _required;
    }
    
    function getSignerCount() public view returns(uint) {
        return _signerCount;
    }
    
    function addSigner(address account) public onlySigner {
        require(_signerCount < MAX_OWNER_COUNT && !isSigner(account));
        if(_multiSig("addSigner") == true) {
            _deleteProposal("addSigner");
            
            _addSigner(account);
            _signerCount += 1;
        }
    }

    function renounceSigner() public onlySigner {
        require(_signerCount > _required);
        if(_multiSig("renounceSigner") == true) {
            _deleteProposal("renounceSigner");
            
            _removeSigner(msg.sender);
            _signerCount -= 1;
        }
    }
    
    function removeSigner(address account) public onlySigner {
        require(_signerCount > _required && isSigner(account));
        if(_multiSig("removeSigner") == true) {
            _deleteProposal("removeSigner");
            
            _removeSigner(account);
            _signerCount -= 1;
        }
    }
    
}