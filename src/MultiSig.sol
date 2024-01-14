// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MultiSig{
    address[] public owners;
    uint public threshold;

    struct Transaction {
        address owner;
        bool executed;
        address to;
        uint value;
        bytes data;

    }

    mapping (uint => mapping (address => bool)) public isApproved;
    mapping (address => bool) public isOwner;

    Transaction[] public txs;

    // Events
    event MultiSig_Transaction_Submit(uint indexed txId, address indexed from, address _to, uint value, bytes data);
    event MultiSig_Transaction_Approved(uint indexed _txId, address indexed _owner);
    event MultiSig_Transaction_Executed(uint indexed _txId);
    event MultiSig_EthDeposited(address indexed sender, uint indexed value);
    event MultiSig_Approve_Revoked(address indexed _owner, uint indexed _txId);

    // Errors
    error MultiSig_Not_Enough_Owners();
    error MultiSig_Invalid_ThreshHold_Specified();
    error MultiSig_Invalid_Owner();
    error MultiSig_Not_Owner();
    error MultiSig_Invalid_To();
    error MultiSig_Invalid_TransactionID();
    error MultiSig_Tx_Already_Approved();
    error MultiSig_Tx_Already_Executed();
    error MultiSig_Transaction_Not_Yet_Confirmed();
    error MultiSig_Transaction_Failed();
    error MultiSig_Tx_Not_Approved();
    error MultiSig_Not_Tx_Owner();
    error MultiSig_Insufficient_Wallet_Balance();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert MultiSig_Not_Owner();
        _;
    }

    modifier hasToExecuted(uint _txId){
        if (txs[_txId].executed) revert MultiSig_Tx_Already_Executed();
        _;
    }

    modifier hasToApproved(uint _txId) {
        if (isApproved[_txId][msg.sender]) revert MultiSig_Tx_Already_Approved();
        _;
    }

    modifier validTxId(uint _txId){
        if (!(_txId < txs.length) ) revert MultiSig_Invalid_TransactionID();
        _;
    }

    constructor(address[] memory _owners, uint _threshold){
        if (_owners.length <= 1) revert MultiSig_Not_Enough_Owners();
        if ( !(_threshold <= _owners.length && _threshold > 0 ) ) revert MultiSig_Invalid_ThreshHold_Specified();

        for (uint i = 0; i < _owners.length; i++){
            if (_owners[i] == address(0)) revert MultiSig_Invalid_Owner();
            if (isOwner[_owners[i]]) revert MultiSig_Invalid_Owner();

            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        threshold = _threshold;
    }

    function submitTx(address _to, uint _value, bytes calldata _data) public onlyOwner() { 
        if (_to == address(0)) revert MultiSig_Invalid_To();
        uint txId = txs.length;
        
        txs.push(
            Transaction({owner: msg.sender, executed: false, to: _to, value: _value, data: _data})
        );
        emit MultiSig_Transaction_Submit(txId, msg.sender, _to, _value, _data);
    }

    function approveTx(uint _txId) public onlyOwner validTxId(_txId) hasToExecuted(_txId) hasToApproved(_txId){

        isApproved[_txId][msg.sender] = true;
        emit MultiSig_Transaction_Approved(_txId, msg.sender);

    }

    function isTxConfirmed(uint _txId) internal view returns(bool){        
        uint numOfConfirms;
        for (uint i = 0; i < owners.length; i++){
            if (isApproved[_txId][owners[i]]) {
                numOfConfirms += 1;
            }
        }

        return numOfConfirms >= threshold;
    }
    function execute(uint _txId) external onlyOwner validTxId(_txId) hasToExecuted(_txId) returns (bytes memory){
        if (!isTxConfirmed(_txId)) revert MultiSig_Transaction_Not_Yet_Confirmed();

        txs[_txId].executed = true;
        Transaction storage transaction = txs[_txId];

        if (transaction.value > address(this).balance) revert MultiSig_Insufficient_Wallet_Balance();

        (bool success, bytes memory returnData) = transaction.to.call{value : transaction.value}(transaction.data);
        if (!success) revert MultiSig_Transaction_Failed();
        
        emit MultiSig_Transaction_Executed(_txId);        
        return returnData;
    }

    function revokeApprove(uint _txId) public onlyOwner validTxId(_txId) hasToExecuted(_txId) {
        if ( !(isApproved[_txId][msg.sender]) ) revert MultiSig_Tx_Not_Approved();
        isApproved[_txId][msg.sender] = false;

        emit MultiSig_Approve_Revoked(msg.sender, _txId);
    }

    function cancelTx(uint _txId) external onlyOwner validTxId(_txId) hasToExecuted(_txId) {
        if (txs[_txId].owner != msg.sender) revert MultiSig_Not_Tx_Owner();
        delete txs[_txId];
    }
    receive() external payable{
        emit MultiSig_EthDeposited(msg.sender, msg.value);
    }
}