// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract MultiSigWallet {
    // The minimum number of signatures required to perform a transaction
    uint256 public requiredSignatures;

    // The list of signatory wallets
    address[] public signatories;

    // The mapping of signatories to their weights, used to calculate the total number of signatures required
    mapping(address => uint256) public signatoryWeights;

    // The total weight of all signatories
    uint256 public totalWeight;

    // The transaction queue, mapping transaction IDs to transaction details
    struct Transaction {
        uint256 value;
        address to;
        bytes data;
    }
    mapping(bytes32 => Transaction) public transactions;

    // The mapping of transaction IDs to the number of signatures received for that transaction
    mapping(bytes32 => uint256) public transactionSignatures;

    // The event emitted when a new transaction is added to the queue
    event NewTransaction(
        bytes32 indexed id,
        uint256 value,
        address to,
        bytes data
    );

    // The event emitted when a transaction is successfully executed
    event Execution(
        bytes32 indexed id,
        address indexed to,
        uint256 value,
        bytes data
    );

    // The event emitted when a transaction is cancelled
    event Cancel(bytes32 indexed id);

    // The constructor sets the required number of signatures and adds the signatories to the wallet
    constructor(uint256 _requiredSignatures, address[] memory _signatories) {
        requiredSignatures = _requiredSignatures;
        signatories = _signatories;

        // Calculate the total weight of all signatories
        for (uint256 i = 0; i < signatories.length; i++) {
            signatoryWeights[signatories[i]] = 1;
            totalWeight += 1;
        }
    }

    // The function to add a new transaction to the queue
    function addTransaction(
        uint256 _value,
        address _to,
        bytes memory _data
    ) public returns(bytes32) {
        // Generate a unique ID for the transaction
        bytes32 id = keccak256(abi.encodePacked(_value, _to, _data));

        // Add the transaction to the queue
        transactions[id] = Transaction(_value, _to, _data);
        transactionSignatures[id] = 0;

        // Emit the NewTransaction event
        emit NewTransaction(id, _value, _to, _data);
        return id;
    }

    // The function to execute a transaction from the queue
    function executeTransaction(bytes32 _id) public {
        // Ensure that the transaction exists and has enough signatures
        require(
            transactions[_id].value > 0,
            "Transaction does not exist or has already been executed"
        );
        require(
            transactionSignatures[_id] >= requiredSignatures,
            "Not enough signatures to execute transaction"
        );

        // Get the transaction details
        uint256 value = transactions[_id].value;
        address to = transactions[_id].to;
        bytes memory data = transactions[_id].data;

        // Reset the transaction details
        transactions[_id] = Transaction(0, address(0), "");
        transactionSignatures[_id] = 0;

        // Execute the transaction
        (bool success, ) = to.call{value: value}(data);
        // Emit the Execution event if the transaction was successful, otherwise cancel the transaction
        if (success) {
            emit Execution(_id, to, value, data);
        } else {
            emit Cancel(_id);
        }
    }

    // The function to add a signature to a transaction in the queue
    function addSignature(bytes32 _id) public {
        // Ensure that the signer is a signatory and that the transaction exists
        require(
            transactions[_id].value > 0,
            "Transaction does not exist or has already been executed"
        );
        require(signatoryWeights[msg.sender] > 0, "Signer is not a signatory");

        // Increment the number of signatures for the transaction
        transactionSignatures[_id] += signatoryWeights[msg.sender];
    }

    // The function to revoke a signatory's access to the wallet
    function revokeSignatory(address _signatory) public {
        // Ensure that the caller is an admin and that the signatory is a valid signatory
        require(
            signatoryWeights[_signatory] > 0,
            "Signatory is not a valid signatory"
        );
        require(isAdmin(), "Only an admin can revoke signatories");
        // Remove the signatory from the list and update the total weight
        totalWeight -= signatoryWeights[_signatory];
        signatoryWeights[_signatory] = 0;
    }

    // The function to check if the caller is an admin
    function isAdmin() public view returns (bool) {
        return msg.sender == signatories[0];
    }
}
