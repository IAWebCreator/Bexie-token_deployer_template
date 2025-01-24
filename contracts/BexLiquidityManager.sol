// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICrocSwapDex {
    function userCmd(uint16 callpath, bytes calldata cmd) external payable returns (bytes memory);
}

contract BexLiquidityManager is Ownable {
    address public bexDex;

    event LiquidityDeployed(
        address indexed token,
        uint256 beraAmount,
        uint256 tokenAmount,
        address liquidityCollector
    );

    constructor(address _bexDex) Ownable(msg.sender) {
        bexDex = _bexDex;
    }

    function setBexDex(address _bexDex) external onlyOwner {
        bexDex = _bexDex;
    }

    function deployLiquidity(
        address token,
        uint256 tokenAmount,
        address liquidityCollector
    ) external payable onlyOwner {
        require(msg.value == 5 ether, "Exactly 5 BERA required for liquidity");
        require(tokenAmount > 0, "No tokens provided for liquidity");

        // Transfer tokens from caller (BondingCurve) to this contract
        bool success = IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        require(success, "Token transfer failed");

        // Approve tokens for BEX DEX
        success = IERC20(token).approve(bexDex, tokenAmount);
        require(success, "Token approval failed");

        // Build command payload
        bytes memory cmd = abi.encodePacked(
            uint8(3),                // code
            token,                   // base token address
            uint256(0),             // poolIdx
            int24(0),               // bidTick
            int24(0),               // askTick
            uint128(msg.value),     // BERA liquidity
            uint128(0),             // limitLower
            uint128(type(uint128).max), // limitHigher
            uint8(0),               // settleFlags
            address(0)              // lpConduit
        );

        // Perform liquidity deployment
        try ICrocSwapDex(bexDex).userCmd{value: msg.value}(2, cmd) {
            emit LiquidityDeployed(token, msg.value, tokenAmount, liquidityCollector);
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("BEX operation failed");
        }
    }

    // Allow contract to receive BERA
    receive() external payable {}
}
