// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";
import "../script/MultiSig.s.sol";

contract MultiSigTest is Test {
    MultiSig multiSig;
    address[] owners;
    uint threshold;

    function setUp() public {
        owners = new address[](3);
        owners[0] = address(this); // The test contract itself is an owner
        owners[1] = address(0x1); // Just a dummy address
        owners[2] = address(0x2); // Another dummy address
        threshold = 2;
        multiSig = new MultiSig(owners, threshold);
    }

    function testInitialOwners() public {
        // Test if the owners are set correctly
        for(uint i = 0; i < owners.length; i++) {
            assertTrue(multiSig.isOwner(owners[i]));
        }
    }

    function testIntializeInvalidOwners() public{
        vm.prank(address(0x3));
        owners = new address[](3);
        owners[0] = address(this); // The test contract itself is an owner
        owners[1] = address(0); // Just a dummy address
        owners[2] = address(0x2); // Another dummy address
        threshold = 2;

        vm.expectRevert(MultiSig.MultiSig_Invalid_Owner.selector);
        multiSig = new MultiSig(owners, threshold);

    }

    function testIntializeInvalidThreshHold() public{
        vm.prank(address(0x3));
        owners = new address[](3);
        owners[0] = address(this); // The test contract itself is an owner
        owners[1] = address(0x1); // Just a dummy address
        owners[2] = address(0x2); // Another dummy address
        threshold = 4;
        vm.expectRevert(MultiSig.MultiSig_Invalid_ThreshHold_Specified.selector);
        multiSig = new MultiSig(owners, threshold);

        threshold = 0;
        vm.expectRevert(MultiSig.MultiSig_Invalid_ThreshHold_Specified.selector);
        multiSig = new MultiSig(owners, threshold);
    }

    function testSubmitTransaction() public {
        // Test if an owner can submit a transaction
        vm.prank(owners[0]);

        vm.expectEmit(true, true, true, true);
        emit MultiSig.MultiSig_Transaction_Submit(0, owners[0], address(0x3), 1 ether, "");
        multiSig.submitTx(address(0x3), 1 ether, "");

    }
    function testInvalidSubmitTransaction() public {
        // Test if an owner can submit a transaction
        vm.prank(owners[0]);

        vm.expectRevert(MultiSig.MultiSig_Invalid_To.selector);
        multiSig.submitTx(address(0), 1 ether, "");

    }

    function testApproveTransaction() public {
        // Test if an owner can approve a transaction
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        assertTrue(multiSig.isApproved(0, owners[1]));
    }

    function testFailApproveTransactionAlreadyApproved() public {
        // Test if an owner cannot approve a transaction more than once
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[1]);
        multiSig.approveTx(0); // This should revert
    }

    function testApproveTransactionAlreadyExecuted() public {
        // Test if an owner cannot approve a transaction that already executed

        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        vm.prank(owners[0]);
        multiSig.execute(0);

        vm.expectRevert(MultiSig.MultiSig_Tx_Already_Executed.selector);
        multiSig.approveTx(0); // This should revert
    }

    function testExecuteTransaction() public {
        // Test if a transaction can be executed after enough approvals
        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        vm.prank(owners[0]);
        
        vm.expectEmit(true, false, false, false);
        emit MultiSig.MultiSig_Transaction_Executed(0);
        multiSig.execute(0);

    }

    function testInvalidTxIdExecuteTransaction() public {
        // Test if a transaction can be executed after enough approvals
        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);

        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        
        vm.prank(owners[0]);
        
        vm.expectRevert(MultiSig.MultiSig_Invalid_TransactionID.selector);
        multiSig.execute(1); // invalid Tx ID
        
        // assertTrue();
    }

    function testAlreadyExecutedExecuteTransaction() public {
        // Test if a transaction can be executed after enough approvals
        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);

        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        
        vm.prank(owners[0]);
        multiSig.execute(0);
        
        vm.expectRevert(MultiSig.MultiSig_Tx_Already_Executed.selector);
        multiSig.execute(0);
        
        // assertTrue();
    }
     function testNoFundsExecuteTransaction() public {
        // Test if a transaction can be executed after enough approvals
        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        vm.prank(owners[0]);
        
        vm.expectRevert(MultiSig.MultiSig_Insufficient_Wallet_Balance.selector);
        multiSig.execute(0);

    }

    function testNotEnoughApprovalsExecuteTransaction() public {
        // Test if a transaction cannot be executed without enough approvals
        vm.deal(owners[0], 10 ether);
        multiSig.submitTx(address(0x3), 1 ether, "");
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);

        vm.prank(owners[1]);
        multiSig.approveTx(0);

        vm.prank(owners[0]);
        vm.expectRevert(MultiSig.MultiSig_Transaction_Not_Yet_Confirmed.selector);
        multiSig.execute(0); // This should revert
    }

    function testRevokeApproval() public {
        // Test if an owner can revoke their approval
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[1]);

        vm.expectEmit(true, true, false, false);
        emit MultiSig.MultiSig_Approve_Revoked(owners[1], 0);
        multiSig.revokeApprove(0);

    }

    function testRevokeApprovalNotApproved() public {
        // Test if an owner cannot revoke an approval that doesn't exist
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);

        vm.expectRevert(MultiSig.MultiSig_Tx_Not_Approved.selector);
        multiSig.revokeApprove(0); // This should revert

    }

    function testRevokeApproveAlreadyExecutedTransaction() public {
        // Test if an executed transaction cannot be executed again
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        vm.prank(owners[0]);
        multiSig.execute(0);
        
        vm.prank(owners[1]);

        vm.expectRevert(MultiSig.MultiSig_Tx_Already_Executed.selector);
        multiSig.revokeApprove(0); // This should revert
    }

    function testCancelTransaction() public {
        // Test if the transaction owner can cancel the transaction
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[0]);
        multiSig.cancelTx(0);
        // Check if the transaction is deleted
        (,bool executed,,,) = multiSig.txs(0);
        assertTrue(!executed); // Since the transaction is deleted, the default value for a bool (false) is expected
    }

    function testExecutedTransactionCancel() public {
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);
        vm.prank(owners[1]);
        multiSig.approveTx(0);
        vm.prank(owners[2]);
        multiSig.approveTx(0);
        vm.prank(owners[0]);
        multiSig.execute(0);
        
        vm.prank(owners[0]);

        vm.expectRevert(MultiSig.MultiSig_Tx_Already_Executed.selector);
        multiSig.cancelTx(0); //should revert
    }

    function testOtherOwnerCancelTransaction() public {
        // Test if the transaction owner can cancel the transaction
        vm.prank(owners[0]);
        multiSig.submitTx(address(0x3), 1 ether, "");
        vm.prank(owners[1]);

        vm.expectRevert(MultiSig.MultiSig_Not_Tx_Owner.selector);
        multiSig.cancelTx(0);
        
    }

    function testCanReceiveEther() public{
        vm.prank(owners[0]);
        (bool success, ) = address(multiSig).call{value:2 ether}(""); // eth required to execute tx
        assertTrue(success);

        assertEq(address(multiSig).balance, 2 ether);
    }


    function testMultiSigScript() public{
        MultiSigScript script = new MultiSigScript();
        script.run();
        bool isDeployed = address(script.multisig()) != address(0);
        assertTrue(isDeployed);
    }
}