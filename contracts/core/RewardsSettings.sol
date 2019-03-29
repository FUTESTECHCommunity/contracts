pragma solidity ^0.4.25;

import '../library/ITyped.sol';
import '../Requirement.sol';

/**
 * VoteRewards
 * CommentRewards
 * 
 */ 

contract RewardsSettings is ITyped, Requirement(1) {
    event ConfirmSetting(bytes32 indexed key, uint256 value, uint timestamp);
    
    mapping(bytes32 => uint256) public _settingValues;
    mapping(bytes32 => bool) public _isSettingValue;
    
    constructor() public {}
    
    function setting(bytes32 key, uint256 value) public onlySigner {
        if(_multiSig("setting") == true) {
            _deleteProposal("setting");
            
            _isSettingValue[key] = true;
            _settingValues[key] = value;
            emit ConfirmSetting(key, value, block.timestamp);
        }
    }
    
    function getBy(bytes32 key) public view returns(uint256) {
        require(_isSettingValue[key]);
        return _settingValues[key];
    }
    
    function getTypeName() public view returns(bytes32) {
        return "RewardsSettings";
    }
}