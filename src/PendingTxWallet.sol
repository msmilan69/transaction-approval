// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendingTxWallet {
    using SafeERC20 for IERC20;

    enum TxStatus { Pending, Approved, Denied, Expired }
    enum TokenType { ETH, ERC20 }

    struct PendingTransaction {
        address to;
        uint256 value;
        address token; // address(0) for ETH
        uint256 timestamp;
        TxStatus status;
        TokenType tokenType;
    }

    // Events
    event TransactionPending(
        uint256 indexed txId,
        address indexed to,
        uint256 value,
        address token,
        TokenType tokenType,
        uint256 timestamp
    );
    
    event TransactionApproved(uint256 indexed txId, address executor);
    event TransactionDenied(uint256 indexed txId, address executor);
    event TransactionExpired(uint256 indexed txId);

    // Constants
    uint256 public constant TIMELOCK_DURATION = 24 hours; // 24 hours timelock

    // State variables
    mapping(uint256 => PendingTransaction) public pendingTransactions;
    uint256 public transactionCount;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ETH transfer function
    function transferETH(address _to, uint256 _value) external onlyOwner {
        require(_value > 0, "Value must be > 0");
        require(_to != address(0), "Invalid recipient");

        uint256 txId = _createPendingTransaction(_to, _value, address(0), TokenType.ETH);
        
        emit TransactionPending(
            txId,
            _to,
            _value,
            address(0),
            TokenType.ETH,
            block.timestamp
        );
    }

    // ERC20 transfer function
    function transferERC20(address _token, address _to, uint256 _value) external onlyOwner {
        require(_value > 0, "Value must be > 0");
        require(_token != address(0), "Invalid token");
        require(_to != address(0), "Invalid recipient");

        uint256 txId = _createPendingTransaction(_to, _value, _token, TokenType.ERC20);
        
        emit TransactionPending(
            txId,
            _to,
            _value,
            _token,
            TokenType.ERC20,
            block.timestamp
        );
    }

    function approveTransaction(uint256 _txId) external onlyOwner {
        PendingTransaction storage txInfo = pendingTransactions[_txId];
        require(txInfo.timestamp > 0, "Transaction does not exist");
        require(txInfo.status == TxStatus.Pending, "Transaction not pending");
        require(block.timestamp <= txInfo.timestamp + TIMELOCK_DURATION, "Transaction expired");

        txInfo.status = TxStatus.Approved;

        // Execute the transfer
        if (txInfo.tokenType == TokenType.ETH) {
            (bool success, ) = txInfo.to.call{value: txInfo.value}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(txInfo.token).safeTransfer(txInfo.to, txInfo.value);
        }

        emit TransactionApproved(_txId, msg.sender);
    }

    function denyTransaction(uint256 _txId) external onlyOwner {
        PendingTransaction storage txInfo = pendingTransactions[_txId];
        require(txInfo.timestamp > 0, "Transaction does not exist");
        require(txInfo.status == TxStatus.Pending, "Transaction not pending");

        txInfo.status = TxStatus.Denied;
        emit TransactionDenied(_txId, msg.sender);
    }

    function cancelExpiredTransaction(uint256 _txId) external {
        PendingTransaction storage txInfo = pendingTransactions[_txId];
        require(txInfo.timestamp > 0, "Transaction does not exist");
        require(txInfo.status == TxStatus.Pending, "Transaction not pending");
        require(block.timestamp > txInfo.timestamp + TIMELOCK_DURATION, "Not expired yet");

        txInfo.status = TxStatus.Expired;
        emit TransactionExpired(_txId);
    }

    function getTransactionStatus(uint256 _txId) external view returns (TxStatus) {
        PendingTransaction storage txInfo = pendingTransactions[_txId];
        if (txInfo.timestamp == 0) return TxStatus.Denied; // Doesn't exist
        
        if (txInfo.status == TxStatus.Pending && 
            block.timestamp > txInfo.timestamp + TIMELOCK_DURATION) {
            return TxStatus.Expired;
        }
        
        return txInfo.status;
    }

    function getPendingTransactions() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= transactionCount; i++) {
            if (pendingTransactions[i].status == TxStatus.Pending && 
                block.timestamp <= pendingTransactions[i].timestamp + TIMELOCK_DURATION) {
                count++;
            }
        }

        uint256[] memory pendingIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= transactionCount; i++) {
            if (pendingTransactions[i].status == TxStatus.Pending && 
                block.timestamp <= pendingTransactions[i].timestamp + TIMELOCK_DURATION) {
                pendingIds[index] = i;
                index++;
            }
        }

        return pendingIds;
    }

    function _createPendingTransaction(
        address _to,
        uint256 _value,
        address _token,
        TokenType _tokenType
    ) internal returns (uint256) {
        transactionCount++;
        pendingTransactions[transactionCount] = PendingTransaction({
            to: _to,
            value: _value,
            token: _token,
            timestamp: block.timestamp,
            status: TxStatus.Pending,
            tokenType: _tokenType
        });

        return transactionCount;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}