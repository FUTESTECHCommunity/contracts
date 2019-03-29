pragma solidity ^0.4.25;

import './IMemberBook.sol';
import '../library/ITyped.sol';
import './MembershipLevel.sol';
import '../Controlled.sol';
import '../Requirement.sol';
import '../library/CloneFactory.sol';
import './Member.sol';

contract MemberBook is Controlled, CloneFactory, ITyped, IMemberBook, Requirement(1) {
    event NewMember(uint256 indexed mID, address indexed account, address assertAccount, uint beginTimestamp, uint endTimestamp, uint level);
    event UpdateMembership(uint256 indexed mID, address indexed account, address assertAccount, uint beginTimestamp, uint endTimestamp, uint level);
    event UpdateBasicInfo(uint256 indexed mID, address account, address assetAccount);
    
    mapping(uint256 => address) private _mIDxMember;//mID => Member
    mapping(address => uint) private _mOpAccountxmID;//operateAccount => mID
    
     /*
     *  Modifiers
     */
    modifier onlyMember(uint mID) {
        require(isMember(mID), "id not exist.");
        _;
    }
    
    modifier onlyMemberAccount(address account) {
        uint256 mID = _mOpAccountxmID[account];
        require(mID > 0, "id not exist.");
        _;
    }
    
    modifier isHuman() {
        address addr = msg.sender;
        uint256 codeLength;
        
        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        _;
    }
    
    constructor() public isHuman() {}
    
    //maintain member informations
    function signUp(uint256 mID, address account, address assetAccount, uint beginTimestamp, uint endTimestamp, uint level) public onlyCaller("Membership") returns(bool) {
        require(endTimestamp >= beginTimestamp, "invalid timestamp range.");
        require(_mIDxMember[mID]  == address(0), "id conflict,member is exist.");
        require(_mOpAccountxmID[account] == 0, "account conflict.");
        require(level > 0, "invalid level.");
        
        Member member = Member(getController().lookup("Member"));
        require(member.initialize(mID, account, account));
        require(member.updateOrAddLevel(level, beginTimestamp, endTimestamp));
        
        _mIDxMember[mID] == address(member);
        _mOpAccountxmID[account] = mID;

        emit NewMember(mID, account, assetAccount, beginTimestamp, endTimestamp, level);
        return true;
    }
    
    function updateBasicInfo(uint256 mID, address account, address assetAccount) public onlyCaller("Membership") returns(bool) {
        require(_mIDxMember[mID] != address(0) && (_mOpAccountxmID[account] == 0 || _mOpAccountxmID[account] == mID), "invalid parameters.");
        
        Member member = Member(_mIDxMember[mID]);
        bool isNewAccount = false;
        address oldAccount = member.getAccount();
        if(_mOpAccountxmID[account] == 0) {
            isNewAccount = true;
        }
        require(member.updateBasicInfo(account, assetAccount));
        if(isNewAccount == true) {
            _mOpAccountxmID[account] = mID;
            delete _mOpAccountxmID[oldAccount];
        }
        emit UpdateBasicInfo(mID, account, assetAccount);
        return true;
    }
    
    function updateMembership(uint256 mID, address account, address assetAccount, uint beginTimestamp, uint endTimestamp, uint level) public onlyCaller("Membership") returns(bool){
        require(_mIDxMember[mID] != address(0) && (_mOpAccountxmID[account] == 0 || _mOpAccountxmID[account] == mID) && level > 0 && endTimestamp > beginTimestamp, "invalid parameters.");
        
        bool isNewAccount = false;
        if(_mOpAccountxmID[account] == 0) {
            isNewAccount = true;
        }
       
        Member member = Member(_mIDxMember[mID]);
        address oldAccount = member.getAccount();
        require(member.updateBasicInfo(account, assetAccount));
        require(member.updateOrAddLevel(level, beginTimestamp, endTimestamp));
        
        if(isNewAccount == true) {
            _mOpAccountxmID[account] = mID;
            delete _mOpAccountxmID[oldAccount];
        }
        emit UpdateMembership(mID, account, assetAccount, beginTimestamp, endTimestamp, level);
        return true;
    }
    
    function getAccount(uint256 mID) public onlyMember(mID) view returns(address) {
        Member member = Member(_mIDxMember[mID]);
        return member.getAccount();
    }
    
    function getAssetAccount(uint256 mID) public onlyMember(mID) view returns(address) {
        Member member = Member(_mIDxMember[mID]);
        return member.getAssetAccount();
    }
    
    function getBasicInfo(uint256 mID) public onlyMember(mID) view returns(uint256, address, address, uint) {
        Member member = Member(_mIDxMember[mID]);
        return member.getBasicInfo();
    }
    
    function getBasicInfo(address account) public onlyMemberAccount(account) view returns(uint256, address, address, uint) {
        uint256 mID = _mOpAccountxmID[account];
        return getBasicInfo(mID);
    }

    function getMember(uint256 mID, uint level) public onlyMember(mID) view returns(uint256, address account, address assetAccount, uint beginTimestamp,uint endTimestamp, uint) {
        require(level > 0);
        Member member = Member(_mIDxMember[mID]);
        return member.getMember(level);
    }
    
    function getMemberLevels(uint256 mID) public onlyMember(mID) view returns(uint[] ,uint[] , uint[] ) {
        Member member = Member(_mIDxMember[mID]);
        return member.getLevels();
    }
    
    function getMember(address account, uint level) public onlyMemberAccount(account) view returns(uint256, address, address , uint , uint , uint) {
       uint256 mID = _mOpAccountxmID[account];
       getMember(mID, level);
    }
    
    function getMemberLevels(address account) public onlyMemberAccount(account) view returns(uint[], uint[], uint[]) {
      uint256 mID = _mOpAccountxmID[account];
      return getMemberLevels(mID);
    }
    
    function isMember(uint256 mID) public view returns(bool) {
        if(_mIDxMember[mID] != address(0))
            return true;
        return false;
    }
    
    function isMember(address account) public view returns(bool) {
        uint256 mID = _mOpAccountxmID[account];
        return isMember(mID);
    }
    
    function isExpired(uint256 mID, uint level) public view returns(bool result) {
        result = true;
        if(isMember(mID) && level > 0) {
            Member member = Member(_mIDxMember[mID]);
            (,,,, uint endTimestamp, ) = member.getMember(level);
            result = endTimestamp < block.timestamp;
        }
    }
    
    function isExpired(address account, uint level) public view returns(bool result) {
        uint256 mID = _mOpAccountxmID[account];
        return isExpired(mID, level);
    }
    
    function updateAccount(uint256 mID, address newAccount) external returns(bool) {
        (, address account, address assetAccount, ) = getBasicInfo(mID);
        require(account == msg.sender, "invalid sender.");
        return updateBasicInfo(mID, newAccount, assetAccount);
    }
    
    function updateAssetAccount(uint256 mID, address newAssetAccount) external returns(bool) {
        (, address account, ,) = getBasicInfo(mID);
        require(account == msg.sender, "invalid sender.");
        return updateBasicInfo(mID, account, newAssetAccount);
    }
    
    function getTypeName() public view returns (bytes32) {
        return "MemberBook";
    }
    
}