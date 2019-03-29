pragma solidity ^0.4.25;

import "./CustodianUpgradeable.sol";
import "./ERC20Impl.sol";

contract ERC20ImplUpgradeable is CustodianUpgradeable  {

    // TYPES
    // The struct type for pending implementation changes.
    struct ImplChangeRequest {
        address proposedNew;
    }

    // MEMBERS
    // The reference to the active token implementation.
    ERC20Impl public erc20Impl;

    // The map of lock ids to pending implementation changes.
    mapping (bytes32 => ImplChangeRequest) public implChangeReqs;

    // CONSTRUCTOR
    constructor(address _custodian) CustodianUpgradeable(_custodian) public {
        erc20Impl = ERC20Impl(0x0);
    }

    // MODIFIERS
    modifier onlyImpl {
        require(msg.sender == address(erc20Impl));
        _;
    }

    // PUBLIC FUNCTIONS
    // (UPGRADE)
    /** @notice  Requests a change of the active implementation associated
      * with this contract.
      *
      * @dev  Returns a unique lock id associated with the request.
      * Anyone can call this function, but confirming the request is authorized
      * by the custodian.
      *
      * @param  _proposedImpl  The address of the new active implementation.
      * @return  lockId  A unique identifier for this request.
      */
    function requestImplChange(address _proposedImpl) public returns (bytes32 lockId) {
        require(_proposedImpl != address(0));

        lockId = generateLockId();

        implChangeReqs[lockId] = ImplChangeRequest({
            proposedNew: _proposedImpl
        });

        emit ImplChangeRequested(lockId, msg.sender, _proposedImpl);
    }

    /** @notice  Confirms a pending change of the active implementation
      * associated with this contract.
      *
      * @dev  When called by the custodian with a lock id associated with a
      * pending change, the `ERC20Impl erc20Impl` member will be updated
      * with the requested address.
      *
      * @param  _lockId  The identifier of a pending change request.
      */
    function confirmImplChange(bytes32 _lockId) public onlyCustodian {
        erc20Impl = getImplChangeReq(_lockId);

        delete implChangeReqs[_lockId];

        emit ImplChangeConfirmed(_lockId, address(erc20Impl));
    }

    // PRIVATE FUNCTIONS
    function getImplChangeReq(bytes32 _lockId) private view returns (ERC20Impl _proposedNew) {
        ImplChangeRequest storage changeRequest = implChangeReqs[_lockId];

        // reject ‘null’ results from the map lookup
        // this can only be the case if an unknown `_lockId` is received
        require(changeRequest.proposedNew != address(0));

        return ERC20Impl(changeRequest.proposedNew);
    }

    /// @dev  Emitted by successful `requestImplChange` calls.
    event ImplChangeRequested(
        bytes32 _lockId,
        address _msgSender,
        address _proposedImpl
    );

    /// @dev Emitted by successful `confirmImplChange` calls.
    event ImplChangeConfirmed(bytes32 _lockId, address _newImpl);
}
