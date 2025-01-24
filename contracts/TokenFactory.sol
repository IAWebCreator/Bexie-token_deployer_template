// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BondingCurve.sol";

contract CustomERC20 is Ownable, ERC20 {
    constructor(
        string memory name, 
        string memory symbol, 
        uint256 initialSupply,
        address owner_
    ) ERC20(name, symbol) Ownable(owner_) {
        // Mint the initial supply to this contract's owner (the factory or bonding curve)
        _mint(owner_, initialSupply * 10**decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

contract TokenFactory is Ownable, ReentrancyGuard {
    uint256 public creationFee = 0.002 ether;
    address public feeCollector;
    address public liquidityManager;
    address public liquidityCollector;

    event TokenCreated(
        address indexed creator,
        address tokenAddress,
        address bondingCurveAddress,
        string name,
        string symbol
    );

    constructor(
        address _feeCollector,
        address _liquidityManager,
        address _liquidityCollector
    ) Ownable(msg.sender) {
        feeCollector = _feeCollector;
        liquidityManager = _liquidityManager;
        liquidityCollector = _liquidityCollector;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address priceFeedAddress
    ) external payable nonReentrant {
        require(msg.value >= creationFee, "Insufficient creation fee");

        // 1) Deploy the ERC20
        CustomERC20 token = new CustomERC20(
            name,
            symbol,
            initialSupply,
            address(this) // Make the Factory the owner initially
        );

        // 2) Deploy the BondingCurve
        BondingCurve curve = new BondingCurve(
            address(token),
            feeCollector,
            priceFeedAddress,
            liquidityManager,
            liquidityCollector
        );

        // Move the initial supply to the BondingCurve
        token.transfer(address(curve), initialSupply * 10**token.decimals());

        // Transfer token ownership to the BondingCurve
        token.transferOwnership(address(curve));

        // Transfer the creation fee to feeCollector
        (bool sent,) = feeCollector.call{value: msg.value}("");
        require(sent, "Fee transfer failed");

        emit TokenCreated(
            msg.sender,
            address(token),
            address(curve),
            name,
            symbol
        );
    }

    // Admin Setters
    function setCreationFee(uint256 _newFee) external onlyOwner {
        creationFee = _newFee;
    }

    function setFeeCollector(address _newCollector) external onlyOwner {
        feeCollector = _newCollector;
    }

    function setLiquidityManager(address _newManager) external onlyOwner {
        liquidityManager = _newManager;
    }
}
