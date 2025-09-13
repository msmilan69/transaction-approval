# Pending Transaction Wallet

A smart contract that requires explicit approval for all outgoing transactions with a 24-hour timelock.

## Features

- **Pending State**: All ETH/ERC20 transfers enter pending state
- **Explicit Approval**: Owner must approve transactions before execution
- **Timelock**: 24-hour expiration for unapproved transactions
- **Transparent Events**: All actions logged on-chain
- **Gas Efficient**: Simple and compact design

## Usage

1. **Deploy**: `forge script script/PendingTxWallet.s.sol:DeployPendingTxWallet --rpc-url <RPC_URL> --broadcast --verify`
2. **Transfer ETH**: `wallet.transferETH(recipient, amount)`
3. **Transfer ERC20**: `wallet.transferERC20(tokenAddress, recipient, amount)`
4. **Approve**: `wallet.approveTransaction(txId)`
5. **Deny**: `wallet.denyTransaction(txId)`

## Events

- `TransactionPending`: When a new transaction is created
- `TransactionApproved`: When a transaction is approved and executed
- `TransactionDenied`: When a transaction is denied
- `TransactionExpired`: When a transaction expires

## Security Features

- Only contract owner can create/approve/deny transactions
- 24-hour timelock for auto-expiration
- SafeERC20 for secure token transfers
- Input validation on all functions
