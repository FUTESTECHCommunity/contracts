pragma solidity ^0.4.25;

// import '../library/access/roles/SignerRole.sol';
import '../library/lifecycle/Initializable.sol';
import './ICuriosity.sol';
import '../library/CloneFactory.sol';
import '../core/FuturerSharesToken.sol';
import '../library/ITyped.sol';
import '../Controlled.sol';
import '../core/RewardsSettings.sol';
import '../member/IMemberBook.sol';
import './CuriosityComment.sol';

contract Curiosity is Controlled, CloneFactory, ITyped, Initializable, ICuriosity {
    event ChangeContent(bytes32 indexed);
    event DeleteCuriosity(address indexed);
    event Vote(address indexed voter, GradeLevel indexed level);
    event Up(bytes32 indexed commentHash, uint256 indexed mID);
    event Down(bytes32 indexed commentHash, uint256 indexed mID);
    event NewComment(bytes32 indexed commentHash, uint256 indexed mID, bytes32 indexed datahash);
    
     /*
     *  Modifiers
     */
    
    modifier validRequirement(uint auditorCount, uint required) {
        require(auditorCount <= MAX_OWNER_COUNT
            && required <= auditorCount
            && required != 0
            && auditorCount != 0);
        _;
    }
    
    modifier onlyAuditor() {
        require(_isAuditor[msg.sender]);
        _;
    }
    
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }
    
    modifier canChangeContent() {
        require(_state == CuriosityState.CREATED || _state == CuriosityState.PUBLISHED);
        _;
    }
    
    modifier onlyValid() {
        require(_state != CuriosityState.DELETED);
        _;
    }
    
    modifier onlyPublished() {
        require(_state == CuriosityState.PUBLISHED);
        _;
    }
    
    modifier needAudit(bytes32 contentHash) {
        require(_isContents[contentHash] && !_isAudits[contentHash] && _state != CuriosityState.DELETED);
        _;
    }
    
    /*
     *  Events
     */
    
    //storage
    //audit
    mapping(address => bool) private _isAuditor;
    address[MAX_OWNER_COUNT] private _auditors;
    uint private _required;
    
    mapping(bytes32 => mapping (address => bool)) public _audits;
    mapping(bytes32 => bool) public _isAudits;
    
    address private _owner;
    CuriosityState private _state = CuriosityState.CREATED;
    bytes32 private _curiosityID;
    uint256 private _authorID;
    bytes32 private _contentHash;
    uint private _timestamp;
    mapping(bytes32 => bool) private _isContents;
    
    IMemberBook private _memberBook;
    IFuturerSharesToken private _sharesToken;
    
    mapping(uint8 => uint256) private _voteLevelxCount;//Level=>Count
    mapping(uint256 => bool) private _hasVote;
    uint256 private _voteCount;
    
    //comment
    mapping(bytes32 => address) private _commentaries;
    uint256 private _commentCount;
    
    mapping(uint256 => uint) private _opLogs;
    
    /*
     *  Constants
     */
    uint constant public MAX_OWNER_COUNT = 50;
    
    constructor()  public {}
    
    function initialize(address[] auditors, uint required, uint256 authorID, bytes32 curiosityID, bytes32 contentHash, IFuturerSharesToken sharesToken) external beforeInitialized validRequirement(auditors.length, required) returns(bool) {
        endInitialization();
        
        for (uint i=0; i<auditors.length; i++) {
            require(!_isAuditor[auditors[i]] && auditors[i] != 0);
            _isAuditor[auditors[i]] = true;
            _auditors[i] = auditors[i];
        }
        // _auditors = auditors;
        _required = required;
        _curiosityID = curiosityID;
        _authorID = authorID;
        _owner = msg.sender;
        _timestamp = block.timestamp;
        _sharesToken = sharesToken;
        _memberBook = IMemberBook(getController().lookup("MemberBook"));
        
        _contentHash = contentHash;
        _isContents[_contentHash] = true;
        if(_checkAuditor(msg.sender)) {
            audit(_contentHash);
        }
        return true;
    }
    
    function getBasicInfo() public returns(bytes32 , uint256 , bytes32 , IFuturerSharesToken, uint ) {
        return (_curiosityID, _authorID, _contentHash, _sharesToken, _timestamp);
    }
    
    function audit(bytes32 contentHash) public onlyAuditor needAudit(contentHash) returns (bool){
        if(contentHash == _contentHash) {//current content
            _audits[contentHash][msg.sender] = true;
            if(_isAuditConfirmed(contentHash)) {
                _state = CuriosityState.PUBLISHED;
                _isAudits[contentHash] = true;
            }else {
                _state = CuriosityState.AUDITING;
            }
            return true;
        }else {//update content
            _audits[contentHash][msg.sender] = true;
            if(_isAuditConfirmed(contentHash)) {
                _isAudits[contentHash] = true;
                _contentHash = contentHash;
            }
            return true;
        }
        return false;
    }
    
    function _isAuditConfirmed(bytes32 contentHash) private view returns(bool) {
        uint count = 0;
        for(uint i = 0; i < _auditors.length; i++) {
            if(_audits[contentHash][_auditors[i]]) {
                count += 1;
            }
            if(count == _required) {
                return true;
            }
        }
        return false;
    }
    
    function update(bytes32 contentHash) public onlyAuditor canChangeContent returns(bool) {
        if(_state == CuriosityState.CREATED) {
            delete _isContents[_contentHash];
            _contentHash = contentHash;
        }
        _isContents[contentHash] = true;
        emit ChangeContent(contentHash);
        return true;
    }
    
    function deleteCuriosity() public onlyAuditor {
        _state = CuriosityState.DELETED;
        emit DeleteCuriosity(address(this));
    }
    
    function getState() public view returns(CuriosityState) {
        return _state;
    }
    
    function _updateState(CuriosityState state) internal returns(bool){
        _state = state;
        return true;
    }
    
    function _checkAuditor(address account) private constant returns (bool){
        for(uint i = 0; i < _auditors.length; i++) {
            if(_auditors[i] == account)
                return true;
        }
        return false;
    }
    
    function vote(GradeLevel level) onlyPublished external returns (bool) {
        (uint256 mID, , address assetAccount, , , ) = _memberBook.getMember(msg.sender, 1);
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1)){
            return false;
        }
        if(!_hasVote[mID]) {
            uint8 key = uint8(level);
            _voteLevelxCount[key] = _voteLevelxCount[key] + 1;
            _hasVote[mID] = true;
            _reward(assetAccount, _voteRewards());
            _voteCount += 1;
            _opLogs[mID] = block.timestamp;
            return true;
        }
        return false;
    }
    
    //hash(mID + level) 
    // ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address)
    function vote(GradeLevel level, uint256 mID, uint8 v, bytes32 r, bytes32 s) onlyPublished external returns (bool){
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1))
            return false;
        if(!_hasVote[mID]) {
            (,address account, address assetAccount, , ,) = _memberBook.getMember(mID, 1);
            bytes32 hash = keccak256(abi.encode(mID, address(this), level));
            address author = ecrecover(hash, v, r, s);
            require(account == author, "unknown account.");
            uint8 key = uint8(level);
            _voteLevelxCount[key] = _voteLevelxCount[key] + 1;
            _reward(assetAccount, _voteRewards());
            _voteCount += 1;
            _opLogs[mID] = block.timestamp;
            return true;
        }
        return false;
    }
    
    //L191, L382, L500, L618, L809, Excellent
    function voteCount() public view returns(uint) {
        // uint result = _voteLevelxCount[uint8(GradeLevel.L191)];
        // result += _voteLevelxCount[uint8(GradeLevel.L382)];
        // result += _voteLevelxCount[uint8(GradeLevel.L500)];
        // result += _voteLevelxCount[uint8(GradeLevel.L618)];
        // result += _voteLevelxCount[uint8(GradeLevel.L809)];
        // result += _voteLevelxCount[uint8(GradeLevel.Excellent)];
        // return result;
        return _voteCount;
    }
    
    function _reward(address account, uint256 value) internal returns(bool) {
        _sharesToken.mintForRewards(account, value);
    }
    
    function _voteRewards() private view returns(uint256) {
        RewardsSettings instance = RewardsSettings(getController().lookup("RewardsSettings"));
        return instance.getBy("VoteRewards");
    }
    
    function _commentRewards() private view returns(uint256) {
        RewardsSettings instance = RewardsSettings(getController().lookup("RewardsSettings"));
        return instance.getBy("CommentRewards");
    }
    
    //hash(mID, this, dataHash, parentHash)
    function comment(uint256 mID, bytes32 parentHash, bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) onlyAuditor onlyPublished external returns(bytes32) {
        require(!_memberBook.isExpired(mID, 1), "invalid member.");
        bytes32 commentHash = keccak256(abi.encode(mID, address(this), dataHash, parentHash));
        require(_commentaries[commentHash] == address(0), "comment repeat.");
        if(parentHash != "00000000000000000000000000000000") {
            require(_commentaries[parentHash] != address(0), "invalid parentHash.");
        }
        address author = ecrecover(commentHash, v, r, s);
        (,address account, address assetAccount, , ,) = _memberBook.getMember(mID, 1);
        require(account == author, "invalid author.");
        
        CuriosityComment instance = CuriosityComment(createClone(getController().lookup("Comment")));
        require(instance.initialize(ICuriosity(this), commentHash, mID, dataHash, parentHash));
        
        if(parentHash != "00000000000000000000000000000000") {
            CuriosityComment parent = _conversion(_commentaries[parentHash]);
            require(parent.addChild(commentHash));
        }
    
        _opLogs[mID] = block.timestamp;
        _reward(assetAccount, _commentRewards());
        _commentCount += 1;
        emit NewComment(commentHash, mID, dataHash);
        return commentHash;
    }
    
    function up(bytes32 commentHash, uint256 mID, uint8 v, bytes32 r, bytes32 s) onlyPublished external returns(bool){
        require(_commentaries[commentHash] != address(0), "invalid comment.");
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1))
            return false;
        bytes32 hash = keccak256(abi.encode(commentHash, address(this), mID));
        address author = ecrecover(hash, v, r, s);
        (,address account , address assetAccount, , , ) = _memberBook.getMember(author, 1);
        require(account == author, "invalid account.");
        return _evaluate(commentHash, mID, account, assetAccount, 1);
    }
    
    function up(bytes32 commentHash) onlyPublished external returns(bool) {
        require(_commentaries[commentHash] != address(0), "invalid comment.");
        (uint256 mID, , address assetAccount, , , ) = _memberBook.getMember(msg.sender, 1);
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1)){
            return false;
        }
        return _evaluate(commentHash, mID, msg.sender, assetAccount, 1);
    }
    
    function down(bytes32 commentHash, uint256 mID, uint8 v, bytes32 r, bytes32 s) onlyPublished external returns(bool) {
        require(_commentaries[commentHash] != address(0), "invalid comment.");
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1))
            return false;
        bytes32 hash = keccak256(abi.encode(commentHash, address(this), mID));
        address author = ecrecover(hash, v, r, s);
        (, address account , address assetAccount, , , ) = _memberBook.getMember(mID, 1);
        require(author == account, "invalid account.");
        return _evaluate(commentHash, mID, account, assetAccount, 2);
    }
    
    function down(bytes32 commentHash) onlyPublished external returns(bool) {
        require(_commentaries[commentHash] != address(0), "invalid comment.");
        (uint256 mID, , address assetAccount, , , ) = _memberBook.getMember(msg.sender, 1);
        require(_opLogs[mID] == 0 || _opLogs[mID] + 30 < block.timestamp, "too often.");
        if(_memberBook.isExpired(mID, 1)){
            return false;
        }
        return _evaluate(commentHash, mID, msg.sender, assetAccount, 2);   
    }
    
    function _conversion(address addr) private pure returns(CuriosityComment) {
        return CuriosityComment(addr);
    }
    
    function _evaluate(bytes32 commentHash, uint256 mID, address account, address assetAccount, uint direction) private returns(bool) {
        CuriosityComment instance = _conversion(_commentaries[commentHash]);
        if(instance.isEvaluate(account)) {
            return true;
        }
        instance.evaluate(account, direction);
        _reward(assetAccount, _voteRewards());
        _opLogs[mID] = block.timestamp;
        if(direction == 1) {
            emit Up(commentHash, mID);
        }else {
            emit Down(commentHash, mID);
        }
        _commentCount += 1;
        return true;
    }
}