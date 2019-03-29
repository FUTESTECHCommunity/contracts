pragma solidity ^0.4.25;

import "../library/lifecycle/Initializable.sol";
import "../library/ITyped.sol";

contract Member is ITyped, Initializable{
    address private _owner;
    
    uint256 private _mID;//会员ID
    address private _account;//会员账户
    address private _assetAccount;//会员资产账户
    uint private _createdTimestamp;
    uint[] _levels;
    mapping(uint => Period) private _periods;
    
    modifier onlyOwner() {
        require(_owner == address(0) || _owner == msg.sender);
        _;
    }
    
    struct Period {
        //有效期
        uint beginTimestamp;
        uint endTimestamp;
        uint level;//等级
    }
    
    constructor() public {}
    
    function initialize(uint256 mID, address account, address assetAccount) beforeInitialized public returns(bool) {
        endInitialization();
        _mID = mID;
        _account = account;
        _assetAccount = assetAccount;
        _createdTimestamp = block.timestamp;
        
        _owner = msg.sender;
        return true;
    }
    
    function updateOrAddLevel(uint level, uint beginTimestamp, uint endTimestamp) public onlyOwner returns(bool) {
        if(_isLevelExist(level)) {
            _periods[level].beginTimestamp = beginTimestamp;
            _periods[level].endTimestamp = endTimestamp;
        }else {
            Period memory period = Period({
                beginTimestamp: beginTimestamp,
                endTimestamp: endTimestamp,
                level: level
            });
            _periods[level] = period;
            _levels.push(level);
        }
        return true;
    }
    
    function _isLevelExist(uint level) internal view returns(bool) {
        for(uint i = 0; i < _levels.length; i++) {
            if(_levels[i] == level) {
                return true;
            }
        }
        return false;
    }
    
    function getBasicInfo() public onlyOwner view returns(uint256, address, address, uint) {
        return (_mID, _account, _assetAccount, _createdTimestamp);
    }
    
    function getAccount() public onlyOwner view returns(address) {
        return _account;
    }
    
    function getAssetAccount() public onlyOwner view returns(address) {
        return _assetAccount;
    }
    
    function updateBasicInfo(address account, address assetAccount) public onlyOwner returns(bool) {
        _account = account;
        _assetAccount = assetAccount;
        return true;
    }
    
    function updateAccount(address newAccount) public onlyOwner returns(bool) {
        _account = newAccount;
        return true;
    }
    
    function updateAssetAccount(address newAssetAccount) public onlyOwner returns(bool) {
        _assetAccount = newAssetAccount;
        return true;
    }
    
    function getLevels() public onlyOwner view returns(uint[] ,uint[] , uint[] ) {
        uint length = _levels.length;
        uint[] memory beginTimestamp = new uint[](length);
        uint[] memory endTimestamp = new uint[](length);
        uint[] memory level = new uint[](length);
        
        for(uint i = 0; i < length; i++) {
          uint li = _levels[i];
          Period memory period = _periods[li];
          beginTimestamp[i] = period.beginTimestamp;
          endTimestamp[i] = period.endTimestamp;
          level[i] = period.level;
        }
        return(level, beginTimestamp, endTimestamp);
    }
    
    function getMember(uint level) public onlyOwner view returns(uint256, address account, address assetAccount, uint beginTimestamp,uint endTimestamp, uint) {
        require(_isLevelExist(level));
        return (_mID, _account, _assetAccount, _periods[level].beginTimestamp, _periods[level].endTimestamp, level);
    }
    
    function getTypeName() public view returns(bytes32) {
        return "Member";
    }
    
}