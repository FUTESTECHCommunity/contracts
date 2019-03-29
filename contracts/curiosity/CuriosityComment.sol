pragma solidity ^0.4.25;

import '../library/lifecycle/Initializable.sol';
import './ICuriosity.sol';

contract CuriosityComment is Initializable {
    bytes32 private _commentHash;
    uint256 private _authorID;
    bytes32 private _dataHash;
    uint private _likes;
    uint private _notlikes;
    bytes32 private _parentHash;//0000000000000000000000000000000000000000000000000000000000000000 64
    uint private _timestamp;
    bytes32[] private _children;
    mapping(address => bool) private _evaluations;
    
    ICuriosity private _curiosity;
    
    modifier onlyCuriosity() {
        require(msg.sender == address(_curiosity));
        _;
    }
    
    constructor () public {}
    
    function initialize(ICuriosity curiosity, bytes32 commentHash, uint256 authorID, bytes32 dataHash, bytes32 parentHash) public beforeInitialized returns(bool) {
        _curiosity = curiosity;
        
        _commentHash = commentHash;
        _authorID = authorID;
        _dataHash = dataHash;
        _parentHash = parentHash;
        
        _timestamp = block.timestamp;
        
        return true;
    }
    
    function getParentHash() public onlyCuriosity view returns(bytes32) {
        return _parentHash;
    }
    
    function isEvaluate(address account) public onlyCuriosity view returns(bool) {
        return _evaluations[account];
    }
    
    function evaluate(address account, uint direction) public onlyCuriosity returns(bool) {
        _evaluations[account] = true;
        if(direction == 1)
            _likes += 1;
        else if(direction == 2)
            _notlikes += 1;
    }
    
    function addChild(bytes32 child) public onlyCuriosity returns(bool) {
        _children.push(child);
        return true;
    }
    
    function getBasicInfo() public view returns(bytes32, uint256, bytes32, bytes32, uint, uint, uint, uint) {
        return (_commentHash, _authorID, _dataHash, _parentHash, _likes, _notlikes, _timestamp, _children.length);
    } 
}