pragma solidity ^0.4.25;
import '../library/token/ERC20/ERC20Burnable.sol';
import '../library/ITyped.sol';
import '../curiosity/ICuriosity.sol';

contract IFuturerSharesToken is ITyped, ERC20Burnable{
    function initialize(ICuriosity curiosity) external returns(bool);
    function mintForRewards(address to, uint256 value) external returns(bool);
    function exchange(address owner, uint256 value) external returns(bool);
}