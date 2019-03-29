pragma solidity ^0.4.25;

import './Controlled.sol';
import './library/lifecycle/Initializable.sol';
import './library/ITyped.sol';


contract ITime is Controlled, ITyped {
    function getTimestamp() external view returns (uint256);
}