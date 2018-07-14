pragma solidity ^0.4.0;

import "./PlasmaCore.sol";
import "./PriorityQueue.sol";


/**
 * @title RootChain
 * @dev Plasma Battleship root chain contract implementation. 
 */
contract RootChain {
    using PlasmaCore for uint256;
    using PlasmaCore for bytes;


    /*
     * Events
     */

    event DepositCreated(
        address indexed owner,
        uint256 amount,
        uint256 depositBlock
    );

    event BlockSubmitted(
        bytes32 root
    );

    event ExitStarted(
        address indexed owner,
        uint256 utxoPosition,
        uint256 amount
    );


    /*
     * Storage
     */

    uint256 constant public CHALLENGE_PERIOD = 1 weeks;
    uint256 constant public EXIT_BOND = 123456789;

    PriorityQueue exitQueue;
    uint256 public currentBlockNumber;
    address public operator;

    mapping (uint256 => PlasmaBlock) public plasmaBlocks;
    mapping (uint256 => PlasmaExit) public plasmaExits;

    struct PlasmaBlock {
        bytes32 root;
    }

    struct PlasmaExit {
        address owner;
        uint256 amount;
    }


    /*
     * Modifiers
     */

    modifier onlyOperator() {
        require(msg.sender == operator);
        _;
    }

    modifier onlyWithValue(uint256 value) {
        require(msg.value == value);
        _;
    }

    
    /*
     * Constructor
     */

    constructor() public {
        operator = msg.sender;
    }


    /*
     * Public functions
     */
    
    function deposit(bytes _encodedDepositTx) public {

    }

    function submitBlock(bytes32 _root) public onlyOperator {

    }

    function startExit(
        uint256 _utxoPosition,
        bytes _encodedTx,
        bytes _txInclusionProof,
        bytes _txSignatures
    ) public onlyWithValue(EXIT_BOND) {

    }

    function challengeExit(
        uint256 _exitingUtxoPosition,
        uint256 _spendingTxPosition,
        uint256 _encodedSpendingTx,
        uint256 _spendingTxInclusionProof,
        uint256 _spendingTxSignatures,
        uint256 _spendingTxConfirmationSignatures
    ) public {
		uint256 eUtxoPos = _encodedSpendingTx.getUtxoPos(_exitingUtxoPosition);

        uint256 _txindex  = (_spendingTxPosition % 1000000000) / 10000;
        bytes32 root = plasmaChain[_spendingTxPosition / 1000000000].root; //need to make plasma chain/child chain
        var txHash = keccak256(_encodedSpendingTx);
        var confirmationHash = keccak256(txHash, root);
        var merkleHash = keccak256(txHash, _spendingTxSignatures);
        address owner = exits[eUtxoPos].owner;

        require(owner == ECRecovery.recover(confirmationHash, _spendingTxConfirmationSignatures));
        require(merkleHash.checkMembership(txindex, root, _spendingTxInclusionProof));

        delete exits[eUtxoPos].owner;

    }

    function processExits() public {
        
    }
}
