pragma solidity ^0.4.0;

import "./ECRecovery.sol";
import "./ByteUtils.sol";
import "./RLPDecode.sol";
import "./RLPEncode.sol";


/**
 * @title PlasmaUtils
 * @dev Utilities for working with and decoding Plasma MVP transactions.
 */
library PlasmaUtils {
    using RLPEncode for bytes;
    using RLPDecode for bytes;
    using RLPDecode for RLPDecode.RLPItem;


    /*
     * Storage
     */

    uint256 constant internal BLOCK_OFFSET = 1000000000;
    uint256 constant internal TX_OFFSET = 10000;

    struct TransactionInput {
        uint256 blknum;
        uint256 txindex;
        uint256 oindex;
    }

    struct TransactionOutput {
        address owner;
        uint256 amount;
    }

    struct Transaction {
        TransactionInput[2] inputs;
        TransactionOutput[2] outputs;
    }

    
    /*
     * Internal functions
     */

    /**
     * @dev Decodes an RLP encoded transaction.
     * @param _tx RLP encoded transaction.
     * @return Decoded transaction.
     */
    function decodeTx(bytes memory _tx) internal pure returns (Transaction) {
        RLPDecode.RLPItem[] memory txList = _tx.toRLPItem().toList();
        RLPDecode.RLPItem[] memory inputs = txList[0].toList();
        RLPDecode.RLPItem[] memory outputs = txList[1].toList();

        Transaction memory decodedTx;
        for (uint i = 0; i < 2; i++) {
            RLPDecode.RLPItem[] memory input = inputs[i].toList();
            decodedTx.inputs[i] = TransactionInput({
                blknum: input[0].toUint(),
                txindex: input[1].toUint(),
                oindex: input[2].toUint()
            });

            RLPDecode.RLPItem[] memory output = outputs[i].toList();
            decodedTx.outputs[i] = TransactionOutput({
                owner: output[0].toAddress(),
                amount: output[1].toUint()
            });
        }

        return decodedTx;
    }

    /**
     * @dev Given a UTXO position, returns the block number.
     * @param _utxoPosition UTXO position to decode.
     * @return The output's block number.
     */
    function getBlockNumber(uint256 _utxoPosition) internal pure returns (uint256) {
        return _utxoPosition / BLOCK_OFFSET;
    }

    /**
     * @dev Given a UTXO position, returns the transaction index.
     * @param _utxoPosition UTXO position to decode.s
     * @return The output's transaction index.
     */
    function getTxIndex(uint256 _utxoPosition) internal pure returns (uint256) {
        return (_utxoPosition % BLOCK_OFFSET) / TX_OFFSET;
    }

    /**
     * @dev Given a UTXO position, returns the output index.
     * @param _utxoPosition UTXO position to decode.
     * @return The output's index.
     */
    function getOutputIndex(uint256 _utxoPosition) internal pure returns (uint8) {
        return uint8(_utxoPosition % TX_OFFSET);
    }

    /**
     * @dev Encodes a UTXO position.
     * @param _blockNumber Block in which the transaction was created.
     * @param _txIndex Index of the transaction inside the block.
     * @param _outputIndex Which output is being referenced.
     * @return The encoded UTXO position.
     */
    function encodeUtxoPosition(
        uint256 _blockNumber,
        uint256 _txIndex,
        uint256 _outputIndex
    ) internal pure returns (uint256) {
        return (_blockNumber * BLOCK_OFFSET) + (_txIndex * TX_OFFSET) + (_outputIndex * 1);
    }

    /**
     * @dev Returns the encoded UTXO position for a given input.
     * @param _txInput Transaction input to encode.
     * @return The encoded UTXO position.
     */
    function getInputPosition(TransactionInput memory _txInput) internal pure returns (uint256) {
        return encodeUtxoPosition(_txInput.blknum, _txInput.txindex, _txInput.oindex); 
    }

    /**
     * @dev Calculates a deposit root given an encoded deposit transaction.
     * @param _encodedDepositTx RLP encoded deposit transaction.
     * @return The deposit root.
     */
    function getDepositRoot(bytes _encodedDepositTx) internal pure returns (bytes32) {
        bytes32 root = keccak256(abi.encodePacked(_encodedDepositTx, new bytes(130)));
        bytes32 zeroHash = keccak256(abi.encodePacked(uint256(0)));
        for (uint256 i = 0; i < 10; i++) {
            root = keccak256(abi.encodePacked(root, zeroHash));
            zeroHash = keccak256(abi.encodePacked(zeroHash, zeroHash));
        }
        return root;
    }

    /**
     * @dev Creates an encoded deposit transaction for an owner and an amount.
     * @param _owner Owner of the deposit.
     * @param _amount Amount to be deposited.
     * @return RLP encoded deposit transaction.
     */
    function getDepositTransaction(address _owner, uint256 _amount) internal pure returns (bytes) {
        // Inputs and second output are constant.
        bytes memory encodedInputs = "\xc8\xc3\x80\x80\x80\xc3\x80\x80\x80";
        bytes memory encodedSecondOutput = "\xd6\x94\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80";
    
        // Encode the first output.
        bytes[] memory firstOutput = new bytes[](2);
        firstOutput[0] = RLPEncode.encodeAddress(_owner);
        firstOutput[1] = RLPEncode.encodeUint(_amount);
        bytes memory encodedFirstOutput = RLPEncode.encodeList(firstOutput);

        // Combine both outputs.
        bytes[] memory outputs = new bytes[](2);
        outputs[0] = encodedFirstOutput;
        outputs[1] = encodedSecondOutput;
        bytes memory encodedOutputs = RLPEncode.encodeList(outputs);

        // Encode the whole transaction;
        bytes[] memory transaction = new bytes[](2);
        transaction[0] = encodedInputs;
        transaction[1] = encodedOutputs;
        return RLPEncode.encodeList(transaction);
    }

    /**
     * @dev Validates signatures on a transaction.
     * @param _txHash Hash of the transaction to be validated.
     * @param _signatures Signatures over the hash of the transaction.
     * @param _confirmationSignatures Signatures attesting that the transaction is in a valid block.
     * @return True if the signatures are valid, false otherwise.
     */
    function validateSignatures(
        bytes32 _txHash,
        bytes _signatures,
        bytes _confirmationSignatures
    ) internal pure returns (bool) {
        // Check that the signature lengths are correct.
        require(_signatures.length % 65 == 0, "Invalid signature length.");
        require(_signatures.length == _confirmationSignatures.length, "Mismatched signature count.");

        for (uint256 offset = 0; offset < _signatures.length; offset += 65) {
            // Slice off one signature at a time.
            bytes memory signature = ByteUtils.slice(_signatures, offset, 65);
            bytes memory confirmationSigature = ByteUtils.slice(_confirmationSignatures, offset, 65);

            // Check that the signatures match.
            bytes32 confirmationHash = keccak256(abi.encodePacked(_txHash));
            if (ECRecovery.recover(_txHash, signature) != ECRecovery.recover(confirmationHash, confirmationSigature)) {
                return false;
            }
        }

        return true;
    }
}
