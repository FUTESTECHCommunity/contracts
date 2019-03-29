pragma solidity ^0.4.25;

import '../core/IFuturerSharesToken.sol';
contract ICuriosity {
    
    enum CuriosityState {
        NOEXIST,
        CREATED,
        AUDITING,
        PUBLISHED,
        DELETED
    }
    
    enum GradeLevel{L191, L382, L500, L618, L809, Excellent}
    
    function initialize(address[] auditors, uint required, uint256 authorID, bytes32 cID, bytes32 contentData, IFuturerSharesToken sharesToken) external returns(bool);
    
    function getBasicInfo() public returns(bytes32 cID, uint256 authorID, bytes32 msgData, IFuturerSharesToken sharesToken, uint timestamp);
    function audit(bytes32 contentHash) public returns(bool);
    
    function update(bytes32 contentHash) public returns(bool);
    function deleteCuriosity() public;
    function getState() public view returns(CuriosityState);
    function _updateState(CuriosityState state) internal returns(bool);
    
    function vote(GradeLevel level) external returns (bool);
    function vote(GradeLevel level, uint256 mID, uint8 v, bytes32 r, bytes32 s) external returns (bool);
    function voteCount() public view returns(uint);
    
    function comment(uint256 mID, bytes32 parentHash, bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) external returns(bytes32);
    function up(bytes32 commentHash, uint256 mID, uint8 v, bytes32 r, bytes32 s) external returns(bool);
    function up(bytes32 commentHash) external returns(bool);
    function down(bytes32 commentHash, uint256 mID, uint8 v, bytes32 r, bytes32 s) external returns(bool);
    function down(bytes32 commentHash) external returns(bool);
}