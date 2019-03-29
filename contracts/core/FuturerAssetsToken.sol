pragma solidity ^0.4.25;
import '../library/token/ERC20/ERC20Burnable.sol';
import '../library/token/ERC20/ERC20Detailed.sol';
import '../Controlled.sol';
import './IFuturerSharesToken.sol';
import '../library/access/roles/SignerRole.sol';

contract FuturerAssetsToken is Controlled, ITyped, ERC20Burnable, ERC20Detailed, SignerRole{
    
    mapping(address => uint) private _seqs;
    mapping(address => bool) private _sharesTokens;
    
    constructor() public ERC20Detailed("Futurer Asserts Token", "FUTAT", 0){}
    
    function getTypeName() public view returns (bytes32) {
        return "FuturerAssetsToken";
    }
    
    function exchange(address sharesToken, address account, uint256 value, uint seq, uint8 v, bytes32 r, bytes32 s) external returns (bool) {
        require(sharesToken != address(0) && sharesToken != address(this) && _sharesTokens[sharesToken] && _seqs[account] == seq && account != address(0) && value > 0);
        bytes32 hash = keccak256(abi.encode(sharesToken, account, value, seq));
        require(account == ecrecover(hash, v, r, s));
        if(IFuturerSharesToken(sharesToken).exchange(account, value)){
            _mint(account, value);
            _seqs[account] += 1;
        }
        return true;
    }
    
    function getSeq() public view returns (uint) {
        return _seqs[msg.sender];
    }
    
    function getSeq(address account) public view returns (uint) {
        return _seqs[account];
    }
    
    function registSharesToken(address sharesToken) external onlySigner returns(bool) {
        _sharesTokens[sharesToken] = true;
    }
    
    function cancleSharesToken(address sharesToken) external onlySigner returns(bool) {
        _sharesTokens[sharesToken] = false;
        return true;
    }
    
    function isRegisted(address sharesToken) external view returns(bool) {
        return _sharesTokens[sharesToken];
    }
    
}