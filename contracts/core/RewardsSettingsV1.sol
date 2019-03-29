pragma solidity ^0.4.25;

import '../library/ITyped.sol';

contract RewardsSettings is ITyped {
    
    event InitiateSetting(bytes32 indexed key, address initiator, uint256 value, uint timestamp);
    event SubmitSetting(bytes32 indexed key, address operator, uint256 value, uint timestamp);
    event ConfirmSetting(bytes32 indexed key, uint256 value, uint timestamp);
    
    struct Setting {
        // bytes32 hash;
        address initiator;
        bytes32 key;
        uint256 value;
        bool isConfirm;
    }
    
    uint constant public MAX_OWNER_COUNT = 50;
    
    mapping(bytes32 => uint256) public _settingValues;
    mapping(bytes32 => bool) public _isSettingValue;
    
    mapping(bytes32 => mapping(address => bool)) _confirmations;
    mapping(bytes32 => Setting) _settings;
    
    address[] public _auditors;
    mapping(address => bool) _isAuditor;
    uint public _required;
    
    
    modifier validRequirement(uint auditorCount, uint required) {
        require(auditorCount <= MAX_OWNER_COUNT
            && required <= auditorCount
            && required != 0
            && auditorCount != 0);
        _;
    }
    
    modifier onlyAuditor() {
        require(_checkAuditor(msg.sender));
        _;
    }
    
    constructor(address[] auditors, uint required) validRequirement(auditors.length, required) public {
       for (uint i=0; i<auditors.length; i++) {
            require(!_isAuditor[auditors[i]] && auditors[i] != 0);
            _isAuditor[auditors[i]] = true;
        }
        _auditors = auditors;
        _required = required;
    }
    
    function setting(bytes32 key, uint256 value) public onlyAuditor returns(bool) {
        bytes32 hash = keccak256(abi.encode(key, value));
        if(_settings[hash].initiator == address(0) ) {
            Setting memory initSetting = Setting(
                // hash,
                msg.sender,
                key,
                value,
                false
            );
            _settings[hash] = initSetting;
            _confirmations[hash][msg.sender] = true;
            emit InitiateSetting(key, msg.sender, value, block.timestamp);
        }
        if(!_confirmations[hash][msg.sender]) {
            _confirmations[hash][msg.sender] = true;
            emit SubmitSetting(key, msg.sender, value, block.timestamp);
        }
        if(!_settings[hash].isConfirm){
            if(_isConfirm(hash)) {
                Setting storage obj = _settings[hash];
                //update new value
                _settingValues[obj.key] = obj.value;
                _isSettingValue[key] = true;
                obj.isConfirm = true;
                emit ConfirmSetting(key, value, block.timestamp);
            }
        }
        return true;
    }
    
    function getBy(bytes32 key) public view returns(uint256) {
        require(_isSettingValue[key]);
        return _settingValues[key];
    }
    
    function _checkAuditor(address addr) internal view returns (bool) {
        for(uint i = 0; i < _auditors.length; i++) {
            if(_auditors[i] == addr) {
                return true;
            }
        }
        return false;
    }
    
    function _isConfirm(bytes32 hash) internal view returns (bool) {
        uint count = 0;
        for(uint i = 0; i < _auditors.length; i++) {
            if(_confirmations[hash][_auditors[i]]) {
                count +=1;
            }
            if(count == _required){
                return true;
            }
        }
        return false;
    }
    
    function getTypeName() public view returns(bytes32) {
        return "RewardsSettings";
    }
}