pragma solidity ^0.4.25;

import '../Controlled.sol';
import '../library/ITyped.sol';
import './MembershipLevel.sol';
import '../Requirement.sol';
import './IMemberBook.sol';
import '../library/token/ERC20/IERC20.sol';

contract Membership is Controlled, ITyped, Requirement(1) {
    event AddLevel(uint indexed level, address erc20, uint amount, uint extension);
    event UpdateLevel(uint indexed level, address erc20, uint amount, uint extension);
    event UpdateAccount(address indexed account);
    
    MembershipLevel.Data private _membershipLevels;//member level => Level
    address private _account;//organization account
    
    modifier isExist(uint level) {
        require(MembershipLevel.isExist(_membershipLevels, level));
        _;
    }
    
    modifier isNotExist(uint level) {
        require(!MembershipLevel.isExist(_membershipLevels, level));
        _;
    }
    
    constructor(address account) public {
        require(account != address(0));
        _account = account;
    }
    
    function changeAccount(address account) onlySigner external {
        require(account != address(0) && account != _account);
        if(_multiSig("changeAccount") == true) {
            _deleteProposal("changeAccount");
            
            _account = account;
            emit UpdateAccount(_account);
        }
    }
    
    function getTypeName() public view returns (bytes32) {
        return "Membership";
    }
    
    /**
     * maintain member level
     */
     
    function addLevel(uint level, address erc20, uint amount, uint extension) onlySigner isNotExist(level) public {
        if(_multiSig("addLevel") == true) {
            _deleteProposal("addLevel");
            
            MembershipLevel.Level memory instance = MembershipLevel.Level({
                level: level,
                erc20: erc20,
                amount: amount,
                extension: extension
            });
            MembershipLevel.addLevel(_membershipLevels, instance);
            emit AddLevel(level, erc20, amount, extension);
        }
        
    }
    
    function updateLevel(uint level, address erc20, uint amount, uint extension) onlySigner isExist(level) external returns(bool) {
        if(_multiSig("updateLevel") == true) {
            _deleteProposal("updateLevel");
            
            MembershipLevel.Level memory instance = MembershipLevel.getLevel(_membershipLevels, level);
            instance.erc20 = erc20;
            instance.amount = amount;
            instance.extension = extension;
            MembershipLevel.updateLevel(_membershipLevels, instance);
            emit UpdateLevel(level, erc20, amount, extension);
        }
        
    }
    
    function getLevel(uint level) isExist(level) public view returns(uint, address, uint256, uint) {
        MembershipLevel.Level memory instance = MembershipLevel.getLevel(_membershipLevels, level);
        return (instance.level, instance.erc20, instance.amount, instance.extension);
    }
    
    function signUp(uint256 mID, address account, address assetAccount) onlySigner external returns(bool) {
        IMemberBook memberService = _getMemberBook();
        MembershipLevel.Level memory instance = MembershipLevel.getLevel(_membershipLevels, 1);
        memberService.signUp(mID, account, assetAccount, block.timestamp, block.timestamp + instance.extension, 1);
    }
    
    function updateMembership(uint256 mID, address account, address assetAccount, uint beginTimestamp, uint endTimestamp, uint level) onlySigner external {
        if(_multiSig("updateMember") == true) {
            _deleteProposal("updateMember");
            
            IMemberBook memberService = _getMemberBook();
            memberService.updateMembership(mID, account, assetAccount, beginTimestamp, endTimestamp, level);
        }
    }
    
    function _getMemberBook() internal view returns(IMemberBook) {
        return IMemberBook(getController().lookup("MemberBook"));
    }
    
    function memberLevelIsExist(IMemberBook memberService, uint256 mID, uint level) private view returns(bool result) {
        result = false;
        (uint[] memory levels, ,) = memberService.getMemberLevels(mID);
        if(levels.length > 0) {
            for(uint i = 0; i < levels.length; i++) {
                if(levels[i] == level) {
                    result = true;
                }
            }
        }
    }
    
    //safe math
    function upgradeMembershipLevel(uint256 mID, uint level) external returns(bool) {
        MembershipLevel.Level memory instance = MembershipLevel.getLevel(_membershipLevels, level);
        
        IMemberBook memberService = _getMemberBook();
        address account;
        address assetAccount;
        uint beginTimestamp;
        uint endTimestamp;
        
        if(memberLevelIsExist(memberService, mID, level)) {
            (, account, assetAccount, beginTimestamp, endTimestamp, ) = memberService.getMember(mID, level);
            if(endTimestamp > block.timestamp) {
                endTimestamp += instance.extension;
            }else {
                beginTimestamp = block.timestamp;
                endTimestamp = block.timestamp + instance.extension;
            }
        }else {
            (, account, assetAccount,) = memberService.getBasicInfo(mID);
            beginTimestamp = block.timestamp;
            endTimestamp = block.timestamp + instance.extension;
        }
        
        if(instance.erc20 != address(0) && instance.amount > 0) {
            IERC20 erc20 = IERC20(instance.erc20);
            require(erc20.transferFrom(msg.sender, _account, instance.amount), "transferFrom failure.");
        }
        
        memberService.updateMembership(mID, account, assetAccount, beginTimestamp, endTimestamp, level);
        return true;
    }
    
}