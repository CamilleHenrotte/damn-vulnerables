// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {WETH, NaiveReceiverPool} from "./NaiveReceiverPool.sol";
import {BasicForwarder} from "./BasicForwarder.sol";

contract FlashLoanReceiver2 is IERC3156FlashBorrower {
    NaiveReceiverPool private pool;
    WETH private weth;

    uint256 private constant FIXED_FEE = 1e18;

    constructor(address _pool) {
        pool = NaiveReceiverPool(_pool);

        weth = pool.weth();
    }
    receive() external payable {}
    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        assembly {
            // gas savings
            if iszero(eq(sload(pool.slot), caller())) {
                mstore(0x00, 0x48f5c3ed)
                revert(0x1c, 0x04)
            }
        }

        if (token != address(pool.weth())) revert NaiveReceiverPool.UnsupportedCurrency();

        uint256 amountToBeRepaid;
        unchecked {
            amountToBeRepaid = amount + fee;
        }

        _executeActionDuringFlashLoan(amount);

        // Return funds to pool
        WETH(payable(token)).approve(address(pool), amountToBeRepaid);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Internal function where the funds received would be used
    function _executeActionDuringFlashLoan(uint256 amount) internal {
        //weth.withdraw(amount);
        //pool.deposit{value: amount}();
        //pool.withdraw(FIXED_FEE, payable(address(this)));
        weth.withdraw(amount);
        bytes[] memory data = new bytes[](1);
        data[0] = (abi.encodeWithSignature("withdraw(uint256,address)", 0, payable(address(this))));

        pool.multicall(data);
    }
}
