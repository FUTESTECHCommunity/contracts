pragma solidity ^0.4.25;

import '../curiosity/Curiosity.sol';
import '../library/access/roles/SignerRole.sol';
import '../curiosity/ICuriosity.sol';
import '../core/IMemberBook.sol';
import '../library/CloneFactory.sol';
import '../Controller.sol';
import '../core/IFuturerSharesToken.sol';
import '../core/FuturerAssetsToken.sol';
import '../library/ITyped.sol';

contract CuriosityFactory is CloneFactory, ITyped, SignerRole {
    
    mapping(bytes32 => address) private _mCIDxCAddr;//curiosityID => Curiosity
    mapping(address => bool) private _mCAddrxExist;//Curiosity Address => exist?
    uint private _totalCount;
    
    modifier validCuriosity(bytes32 cID) {
        require(_mCIDxCAddr[cID] != address(0));
        _;
    }
    
   /*
     *  Events
     */
    constructor(address[] memory signers) public{
        for(uint i = 0; i < signers.length; i++) {
            _addSigner(signers[i]);
        }
        _totalCount = 0;
    }
    
    //create curiosity
    function createCuriosity(Controller controller, address[] memory auditors, uint required, uint256 mID, bytes32 msgData) public onlySigner returns(ICuriosity) {
        IMemberBook member = IMemberBook(controller.lookup("MemberBook"));
        require(member.isMember(mID) && !member.isExpired(mID, 1));
        
        bytes32 cID = keccak256(abi.encode(mID, _totalCount));
        ICuriosity curiosity = ICuriosity(createClone(controller.lookup("Curiosity")));
        IControlled(curiosity).setController(controller);
        
        IFuturerSharesToken sharesToken = IFuturerSharesToken(createClone(controller.lookup("FuturerSharesToken")));
        IControlled(sharesToken).setController(controller);
        
        curiosity.initialize(auditors, required, mID, cID, msgData, sharesToken);
        sharesToken.initialize(curiosity);
        
        FuturerAssetsToken assetsToken = FuturerAssetsToken(controller.lookup("FuturerAssetsToken"));
        assetsToken.registSharesToken(sharesToken);
        
        _mCIDxCAddr[cID] = curiosity;
        _mCAddrxExist[curiosity] = true;
        _totalCount += 1;
        
        return curiosity;
    }
    
    function totalCount() public view returns(uint) {
        return _totalCount;
    }
    
    function isCuriosity(address addr) public view returns(bool) {
        return _mCAddrxExist[addr];
    }
    
    function isCuriosity(bytes32 cID) public view returns(bool) {
        return _mCIDxCAddr[cID] != address(0);
    }
    
    function getCuriosity(bytes32 cID) public view returns(address) {
        return _mCIDxCAddr[cID];
    }
    
    function getTypeName() public view returns (bytes32) {
        return "CuriosityFactory";
    }
}