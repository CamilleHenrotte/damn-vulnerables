// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}

contract TrusterAttacker {
    TrusterLenderPool public immutable pool;
    DamnValuableToken public immutable token;
    address public immutable player;
    constructor(address _pool, address _player) {
        pool = TrusterLenderPool(_pool);
        token = pool.token();
        player = _player;
    }
    function attack(uint256 amount) external {
        token.approve(player, amount);
        token.transfer(address(pool), amount);
    }
}
