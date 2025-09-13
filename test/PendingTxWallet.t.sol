// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PendingTxWallet.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    
    constructor(uint256 initialSupply) {
        balanceOf[msg.sender] = initialSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract PendingTxWalletTest is Test {
    PendingTxWallet public wallet;
    MockERC20 public mockToken;
    address public owner = address(0x1);
    address public recipient = address(0x2);
    
    function setUp() public {
        vm.prank(owner);
        wallet = new PendingTxWallet();
        
        mockToken = new MockERC20(1000 ether);
        vm.deal(address(wallet), 10 ether);
    }
    
    function test_ETHTransferPending() public {
        vm.prank(owner);
        wallet.transferETH(recipient, 1 ether);
        
        (address to, uint256 value, address token, uint256 timestamp, PendingTxWallet.TxStatus status, PendingTxWallet.TokenType tokenType) = 
            wallet.pendingTransactions(1);
        
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(token, address(0));
        assertEq(uint256(status), uint256(PendingTxWallet.TxStatus.Pending));
        assertEq(uint256(tokenType), uint256(PendingTxWallet.TokenType.ETH));
    }
    
    function test_ERC20TransferPending() public {
        vm.prank(owner);
        wallet.transferERC20(address(mockToken), recipient, 100 ether);
        
        (address to, uint256 value, address token, , PendingTxWallet.TxStatus status, PendingTxWallet.TokenType tokenType) = 
            wallet.pendingTransactions(1);
        
        assertEq(to, recipient);
        assertEq(value, 100 ether);
        assertEq(token, address(mockToken));
        assertEq(uint256(status), uint256(PendingTxWallet.TxStatus.Pending));
        assertEq(uint256(tokenType), uint256(PendingTxWallet.TokenType.ERC20));
    }
    
    function test_ApproveETHTransaction() public {
        uint256 initialBalance = recipient.balance;
        
        vm.prank(owner);
        wallet.transferETH(recipient, 1 ether);
        
        vm.prank(owner);
        wallet.approveTransaction(1);
        
        assertEq(recipient.balance, initialBalance + 1 ether);
        
        (, , , , PendingTxWallet.TxStatus status, ) = wallet.pendingTransactions(1);
        assertEq(uint256(status), uint256(PendingTxWallet.TxStatus.Approved));
    }
    
    function test_DenyTransaction() public {
        vm.prank(owner);
        wallet.transferETH(recipient, 1 ether);
        
        vm.prank(owner);
        wallet.denyTransaction(1);
        
        (, , , , PendingTxWallet.TxStatus status, ) = wallet.pendingTransactions(1);
        assertEq(uint256(status), uint256(PendingTxWallet.TxStatus.Denied));
    }
    
    function test_TransactionExpiration() public {
        vm.prank(owner);
        wallet.transferETH(recipient, 1 ether);
        
        // Fast forward past timelock
        vm.warp(block.timestamp + 25 hours);
        
        wallet.cancelExpiredTransaction(1);
        
        (, , , , PendingTxWallet.TxStatus status, ) = wallet.pendingTransactions(1);
        assertEq(uint256(status), uint256(PendingTxWallet.TxStatus.Expired));
    }
    
    function test_NonOwnerCannotApprove() public {
        vm.prank(owner);
        wallet.transferETH(recipient, 1 ether);
        
        vm.prank(recipient); // Not owner
        vm.expectRevert("Only owner");
        wallet.approveTransaction(1);
    }
}