pragma solidity ^0.4.25;

import '../Controlled.sol';
import './IFuturerSharesToken.sol';
import '../library/lifecycle/Initializable.sol';
import '../curiosity/ICuriosity.sol';

contract FuturerSharesToken is Controlled, ITyped, Initializable, IFuturerSharesToken {
    string constant public name = "Futurer Shares Token";
    uint8 constant public decimals = 0;
    string constant public symbol = "FUTST";
    
    ICuriosity private _curiosity;
    
    function initialize(ICuriosity curiosity) external beforeInitialized returns(bool) {
        endInitialization();
        _curiosity = curiosity;
        return true;
    }
    
    function mintForRewards(address account, uint256 value) external returns(bool) {
        require(msg.sender == address(_curiosity));
        _mint(account, value);
        return true;
    }
    
    function getTypeName() public view returns (bytes32) {
        return "FuturerSharesToken";
    }
    
    function exchange(address account, uint256 value) external onlyCaller("FuturerAssertsToken") returns(bool) {
        _burnFrom(account, value);
        return true;
    }
}