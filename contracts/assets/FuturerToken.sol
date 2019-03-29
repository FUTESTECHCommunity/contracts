pragma solidity ^0.4.25;
import '../library/token/ERC20/ERC20Mintable.sol';
import '../library/token/ERC20/ERC20Detailed.sol';

contract FuturerToken is ERC20Mintable, ERC20Detailed {
    uint256 public constant INITIAL_SUPPLY = 20000000 * (10 ** uint256(18));
    
    constructor() public ERC20Detailed("FuturerToken", "FUT", 18){
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}