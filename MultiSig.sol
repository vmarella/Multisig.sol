//SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract multisig {

    // Define Events
    event Deposit(address indexed sender, uint amount, uint balance);

    event SubmitTransaction(address indexed owner,
                uint indexed txIndex,
                address indexed to,
                uint value,
                bytes data
                );
    
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);

    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    event RevokeConfirmation(address indexed owner, uint indexed txIndex);

    // Define state variables

    address[] public owners;

    mapping(address => bool) isOwner; //address is owner or not

    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed; //if transaction is executed
        mapping(address => bool) isConfirmed;  //transaction is confirmed
        uint numConfirmations; // number of confirmations in the transactions
    }

    Transaction[] public transactions;

    // Define Constructors

    constructor(address[] memory _owners, uint _numConfirmationsRequired) public {
        require(_owners.length>0, "owners required");
        require(
            _numConfirmationsRequired > 0 && numConfirmationsRequired <=_owners.length,
            "Invalid number of Confirmation required was selected.");

        for(uint i=0;i<_owners.length;i++) {
            address owner = _owners[i];

            require(owner!=address(0), "invalid owner"); //making sure the owner is not equal to Zero address
            require(!isOwner[owner], "Owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Defining the modifiers for the functions

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exists.");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "tx already confirmed");
        _;
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) 
    public 
    onlyOwner
     {
         uint txIndex = transactions.length;

         transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0}));

         emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
     }

    function confirmTransaction(uint _txIndex) 
        public
        onlyOwner
        txExists(_txIndex)           // check if the transaction exists
        notExecuted(_txIndex)       // check if the transaction is not executed
        notConfirmed(_txIndex)      // check if the transaction is not confirmed
         {
            Transaction storage transaction = transactions[_txIndex];

            transaction.isConfirmed[msg.sender] = true;

            transaction.numConfirmations += 1;

            emit ConfirmTransaction(msg.sender, _txIndex);

         }

    /*
    function () payable external {
            emit Deposit(msg.sender,msg.value, address(this).balance);
    }
    */

    function deposit() payable external {
        emit Deposit(msg.sender,msg.value,address(this).balance);
    }

    function executeTransaction(uint _txIndex)
    public onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute Transaction"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call.value(transaction.value)(transaction.data); //Execute the transaction
        require(success, "tx Failed"); // checking the call is successful

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation() public {}
}