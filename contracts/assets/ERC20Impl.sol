pragma solidity ^0.4.25;

import "./CustodianUpgradeable.sol";
import "./ERC20Proxy.sol";
import "./ERC20Store.sol";

contract ERC20Impl is CustodianUpgradeable {

    // TYPES
    /// @dev  The struct type for pending increases to the token supply (print).
    struct PendingPrint {
        address receiver;
        uint256 value;
        bytes32 hash;
    }
    
    struct Authorization {
        address operator;
        bool isAdd;
    }

    // MEMBERS
    /// @dev  The reference to the proxy.
    ERC20Proxy public erc20Proxy;

    /// @dev  The reference to the store.
    ERC20Store public erc20Store;

    /// @dev  The map of lock ids to pending token increases.
    mapping (bytes32 => PendingPrint) public pendingPrintMap;
    
    mapping (bytes32 => Authorization) public authorizationMap;
    
    mapping (address => bool) public authorizations;

    // CONSTRUCTOR
    constructor(
          address _erc20Proxy,
          address _erc20Store,
          address _custodian
    ) CustodianUpgradeable(_custodian) public 
    {
        erc20Proxy = ERC20Proxy(_erc20Proxy);
        erc20Store = ERC20Store(_erc20Store);
    }

    // MODIFIERS
    modifier onlyProxy {
        require(msg.sender == address(erc20Proxy));
        _;
    }

    /** @notice  Core logic of the ERC20 `approve` function.
      *
      * @dev  This function can only be called by the referenced proxy,
      * which has an `approve` function.
      * Every argument passed to that function as well as the original
      * `msg.sender` gets passed to this function.
      * NOTE: approvals for the zero address (unspendable) are disallowed.
      *
      * @param  _sender  The address initiating the approval in proxy.
      */
    function approveWithSender(
        address _sender,
        address _spender,
        uint256 _value
    ) public onlyProxy returns (bool success) {
        require(_spender != address(0)); // disallow unspendable approvals
        erc20Store.setAllowance(_sender, _spender, _value);
        erc20Proxy.emitApproval(_sender, _spender, _value);
        return true;
    }

    /** @notice  Core logic of the `increaseApproval` function.
      *
      * @dev  This function can only be called by the referenced proxy,
      * which has an `increaseApproval` function.
      * Every argument passed to that function as well as the original
      * `msg.sender` gets passed to this function.
      * NOTE: approvals for the zero address (unspendable) are disallowed.
      *
      * @param  _sender  The address initiating the approval.
      */
    function increaseApprovalWithSender(
        address _sender,
        address _spender,
        uint256 _addedValue
    ) public onlyProxy returns (bool success) {
        require(_spender != address(0)); // disallow unspendable approvals
        uint256 currentAllowance = erc20Store.allowed(_sender, _spender);
        uint256 newAllowance = currentAllowance + _addedValue;

        require(newAllowance >= currentAllowance);

        erc20Store.setAllowance(_sender, _spender, newAllowance);
        erc20Proxy.emitApproval(_sender, _spender, newAllowance);
        return true;
    }

    /** @notice  Core logic of the `decreaseApproval` function.
      *
      * @dev  This function can only be called by the referenced proxy,
      * which has a `decreaseApproval` function.
      * Every argument passed to that function as well as the original
      * `msg.sender` gets passed to this function.
      * NOTE: approvals for the zero address (unspendable) are disallowed.
      *
      * @param  _sender  The address initiating the approval.
      */
    function decreaseApprovalWithSender(
        address _sender,
        address _spender,
        uint256 _subtractedValue
    ) public onlyProxy returns (bool success) {
        require(_spender != address(0)); // disallow unspendable approvals
        uint256 currentAllowance = erc20Store.allowed(_sender, _spender);
        uint256 newAllowance = currentAllowance - _subtractedValue;

        require(newAllowance <= currentAllowance);

        erc20Store.setAllowance(_sender, _spender, newAllowance);
        erc20Proxy.emitApproval(_sender, _spender, newAllowance);
        return true;
    }

    /** @notice  Requests an increase in the token supply, with the newly created
      * tokens to be added to the balance of the specified account.
      *
      * @dev  Returns a unique lock id associated with the request.
      * Anyone can call this function, but confirming the request is authorized
      * by the custodian.
      * NOTE: printing to the zero address is disallowed.
      *
      * @param  _receiver  The receiving address of the print, if confirmed.
      * @param  _value  The number of tokens to add to the total supply and the
      * balance of the receiving address, if confirmed.
      *
      * @return  lockId  A unique identifier for this request.
      */
    function requestPrint(address _receiver, uint256 _value, bytes32 _hash) public returns (bytes32 lockId) {
        require(_receiver != address(0));

        lockId = generateLockId();

        pendingPrintMap[lockId] = PendingPrint({
            receiver: _receiver,
            value: _value,
            hash: _hash
        });

        emit PrintingLocked(lockId, _receiver, _value, _hash);
    }

    /** @notice  Confirms a pending increase in the token supply.
      *
      * @dev  When called by the custodian with a lock id associated with a
      * pending increase, the amount requested to be printed in the print request
      * is printed to the receiving address specified in that same request.
      * NOTE: this function will not execute any print that would overflow the
      * total supply, but it will not revert either.
      *
      * @param  _lockId  The identifier of a pending print request.
      */
    function confirmPrint(bytes32 _lockId) public onlyCustodian {
        PendingPrint memory print = pendingPrintMap[_lockId];

        // reject ‘null’ results from the map lookup
        // this can only be the case if an unknown `_lockId` is received
        address receiver = print.receiver;
        require (receiver != address(0));
        uint256 value = print.value;

        delete pendingPrintMap[_lockId];

        uint256 supply = erc20Store.totalSupply();
        uint256 newSupply = supply + value;
        if (newSupply >= supply) {
          erc20Store.setTotalSupply(newSupply);
          erc20Store.addBalance(receiver, value);

          emit PrintingConfirmed(_lockId, receiver, value, print.hash);
          erc20Proxy.emitTransfer(address(0), receiver, value);
        }
    }
    
    function requestAuthorization(address _operator) public returns(bytes32 lockId) {
        require(_operator != address(0));
        require(authorizations[_operator] == false);

        lockId = generateLockId();

        authorizationMap[lockId] = Authorization({
            operator: _operator,
            isAdd: true
        });

        emit RequestAuthorizationLocked(lockId, msg.sender, _operator);
    }
    
    function removeAuthorization(address _operator) public returns(bytes32 lockId) {
        require(_operator != address(0));
        require(authorizations[_operator] == true);
        
        lockId = generateLockId();
        
        authorizationMap[lockId] = Authorization({
            operator: _operator,
            isAdd: false
        });
        
        emit RemoveAuthorizationLocked(lockId, msg.sender, _operator);
    }
    
    function confirmAuthorization(bytes32 _lockId) public onlyCustodian returns(bool success) {
        Authorization memory instance = authorizationMap[_lockId];
        
        require(instance.operator != address(0));
        
        delete authorizationMap[_lockId];
        
        if(instance.isAdd) {
            authorizations[instance.operator] = true;
        }else {
            authorizations[instance.operator] = false;
        }
        emit AuthorizationConfirmed(_lockId, instance.operator, instance.isAdd);
        return true;
    }

    /** @notice  Burns the specified value from the sender's balance.
      *
      * @dev  Sender's balanced is subtracted by the amount they wish to burn.
      *
      * @param  _value  The amount to burn.
      *
      * @return  success  true if the burn succeeded.
      */
    function burn(uint256 _value) public returns (bool success) {
        uint256 balanceOfSender = erc20Store.balances(msg.sender);
        require(_value <= balanceOfSender);

        erc20Store.setBalance(msg.sender, balanceOfSender - _value);
        erc20Store.setTotalSupply(erc20Store.totalSupply() - _value);

        erc20Proxy.emitTransfer(msg.sender, address(0), _value);

        return true;
    }
    
    function _isAuthorized(address[] addrs) private view returns(bool) {
        for(uint i = 0; i < addrs.length; i++) {
            if(!authorizations[addrs[i]])
                return false;
        }
        return true;
    }

    /** @notice  A function for a sender to issue multiple transfers to multiple
      * different addresses at once. This function is implemented for gas
      * considerations when someone wishes to transfer, as one transaction is
      * cheaper than issuing several distinct individual `transfer` transactions.
      *
      * @dev  By specifying a set of destination addresses and values, the
      * sender can issue one transaction to transfer multiple amounts to
      * distinct addresses, rather than issuing each as a separate
      * transaction. The `_tos` and `_values` arrays must be equal length, and
      * an index in one array corresponds to the same index in the other array
      * (e.g. `_tos[0]` will receive `_values[0]`, `_tos[1]` will receive
      * `_values[1]`, and so on.)
      * NOTE: transfers to the zero address are disallowed.
      *
      * @param  _tos  The destination addresses to receive the transfers.
      * @param  _values  The values for each destination address.
      * @return  success  If transfers succeeded.
      */
    function batchTransfer(address[] _tos, uint256[] _values) public returns (bool success) {
        require(_tos.length == _values.length);
        require(authorizations[msg.sender] || _isAuthorized(_tos));

        uint256 numTransfers = _tos.length;
        uint256 senderBalance = erc20Store.balances(msg.sender);

        for (uint256 i = 0; i < numTransfers; i++) {
          address to = _tos[i];
          require(to != address(0));
          uint256 v = _values[i];
          require(senderBalance >= v);

          if (msg.sender != to) {
            senderBalance -= v;
            erc20Store.addBalance(to, v);
          }
          erc20Proxy.emitTransfer(msg.sender, to, v);
        }

        erc20Store.setBalance(msg.sender, senderBalance);

        return true;
    }

    /** @notice  Core logic of the ERC20 `transferFrom` function.
      *
      * @dev  This function can only be called by the referenced proxy,
      * which has a `transferFrom` function.
      * Every argument passed to that function as well as the original
      * `msg.sender` gets passed to this function.
      * NOTE: transfers to the zero address are disallowed.
      *
      * @param  _sender  The address initiating the transfer in proxy.
      */
    function transferFromWithSender(
        address _sender,
        address _from,
        address _to,
        uint256 _value
    )
        public
        onlyProxy
        returns (bool success)
    {
        require(_to != address(0)); // ensure burn is the cannonical transfer to 0x0
        
        // require(authorizations[_sender] || authorizations[_to]);
        require(authorizations[_sender]);

        uint256 balanceOfFrom = erc20Store.balances(_from);
        require(_value <= balanceOfFrom);

        uint256 senderAllowance = erc20Store.allowed(_from, _sender);
        require(_value <= senderAllowance);

        erc20Store.setBalance(_from, balanceOfFrom - _value);
        erc20Store.addBalance(_to, _value);

        erc20Store.setAllowance(_from, _sender, senderAllowance - _value);

        erc20Proxy.emitTransfer(_from, _to, _value);

        return true;
    }

    /** @notice  Core logic of the ERC20 `transfer` function.
      *
      * @dev  This function can only be called by the referenced proxy,
      * which has a `transfer` function.
      * Every argument passed to that function as well as the original
      * `msg.sender` gets passed to this function.
      * NOTE: transfers to the zero address are disallowed.
      *
      * @param  _sender  The address initiating the transfer in proxy.
      */
    function transferWithSender(
        address _sender,
        address _to,
        uint256 _value
    )
        public
        onlyProxy
        returns (bool success)
    {
        require(_to != address(0)); // ensure burn is the cannonical transfer to 0x0
        require(authorizations[_sender] || authorizations[_to]);

        uint256 balanceOfSender = erc20Store.balances(_sender);
        require(_value <= balanceOfSender);

        erc20Store.setBalance(_sender, balanceOfSender - _value);
        erc20Store.addBalance(_to, _value);

        erc20Proxy.emitTransfer(_sender, _to, _value);

        return true;
    }

    // METHODS (ERC20 sub interface impl.)
    /// @notice  Core logic of the ERC20 `totalSupply` function.
    function totalSupply() public view returns (uint256) {
        return erc20Store.totalSupply();
    }

    /// @notice  Core logic of the ERC20 `balanceOf` function.
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return erc20Store.balances(_owner);
    }

    /// @notice  Core logic of the ERC20 `allowance` function.
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return erc20Store.allowed(_owner, _spender);
    }

    // EVENTS
    /// @dev  Emitted by successful `requestPrint` calls.
    event PrintingLocked(bytes32 _lockId, address _receiver, uint256 _value, bytes32 _hash);
    /// @dev Emitted by successful `confirmPrint` calls.
    event PrintingConfirmed(bytes32 _lockId, address _receiver, uint256 _value, bytes32 _hash);
    
    event RequestAuthorizationLocked(bytes32 _lockId, address _sender, address _operator);
    event RemoveAuthorizationLocked(bytes32 _lockId, address _sender, address _operator);
    event AuthorizationConfirmed(bytes32 _lockId, address _operator, bool _isAdd);
}