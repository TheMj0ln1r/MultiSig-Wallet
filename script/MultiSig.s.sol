// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract MultiSigScript is Script {
    MultiSig public multisig;
    function run() public {
        vm.startBroadcast();
        address[] memory owners = new address[](4);
        owners[0] = address(0x1);
        owners[1] = address(0x2);
        owners[2] = address(0x3);
        owners[3] = address(0x4);
        uint threshhold = 3;
        multisig = new MultiSig(owners, threshhold);
        vm.stopBroadcast();
    }
}
