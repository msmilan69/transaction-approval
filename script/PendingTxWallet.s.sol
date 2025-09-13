// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PendingTxWallet.sol";

contract DeployPendingTxWallet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        PendingTxWallet wallet = new PendingTxWallet();
        
        console.log("PendingTxWallet deployed at:", address(wallet));
        console.log("Owner:", vm.addr(deployerPrivateKey));
        console.log("Timelock duration: 24 hours");
        
        vm.stopBroadcast();
    }
}