pragma solidity ^0.4.25;

interface IMemberBook {
    
    function isExpired(uint256 mID, uint level) external view returns(bool);
    function isExpired(address account, uint level) external view returns(bool);
    function isMember(uint256 mID) external view returns(bool);
    
    function updateBasicInfo(uint256 mID, address account, address assetAccount) external returns(bool);
    function getBasicInfo(uint256 mID) external view returns(uint256, address, address, uint);
    function getBasicInfo(address account) external view returns(uint256, address, address, uint);
    
    function getMemberLevels(uint256 mID) external view returns(uint[] level, uint[] beginTimestamp, uint[] endTimestamp);
    function getMemberLevels(address account) external view returns(uint[] level, uint[] beginTimestamp, uint[] endTimestamp);
    
    function getMember(uint256 mID, uint level) external view returns(uint256, address, address, uint, uint, uint);
    function getMember(address account, uint level) external view returns(uint256, address, address, uint, uint, uint);
    
    function signUp(uint256 mID, address account, address assetAccount, uint beginTimestamp, uint endTimestamp, uint level) external returns(bool);
    function updateMembership(uint256 mID, address account, address assetAccount, uint beginTimestamp, uint endTimestamp, uint level) external returns(bool);

    function getAccount(uint256 mID) external view returns(address);
    function getAssetAccount(uint256 mID) external view returns(address);
    function updateAccount(uint256 mID, address newAccount) external returns(bool);
    function updateAssetAccount(uint256 mID, address newAssetAccount) external returns(bool);
    
}