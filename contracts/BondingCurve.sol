// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface ICustomERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
}

interface IBexLiquidityManager {
    function deployLiquidity(
        address token,
        uint256 tokenAmount,
        address liquidityCollector
    ) external payable;
}

contract BondingCurve is Ownable, ReentrancyGuard {
    ICustomERC20 public token;
    address public feeCollector;
    address public liquidityManager;
    address public liquidityCollector;
    AggregatorV3Interface internal priceFeed;

    // Supply constants
    uint256 public totalSupplyTokens;
    uint256 public constant TOTAL_TOKENS = 1_000_000_000 * 1e18; 
    uint256 public constant TOKEN_SOLD_THRESHOLD = 800_000_000 * 1e18; 

    // Pricing
    uint256 public constant FEE_PERCENT = 2; 
    uint256 public constant BERA_RAISED_THRESHOLD = 6 ether; 
    uint256 public constant INITIAL_PRICE_MULTIPLIER = 7; 
    uint256 public constant FINAL_PRICE_MULTIPLIER = 75; 
    uint256 public constant PRICE_DECIMALS = 1e6; 

    // Price feed updates
    uint256 public lastBeraPrice; 
    uint256 public lastUpdateTime;
    uint256 public constant UPDATE_INTERVAL = 1 hours;

    // Tracking
    uint256 public collectedBeraUSD;
    bool public liquidityDeployed;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 beraSpent);
    event TokensSold(address indexed seller, uint256 amount, uint256 beraReceived);
    event LiquidityDeployedToBex(uint256 beraAmount, uint256 tokenAmount);

    constructor(
        address _token, 
        address _feeCollector,
        address _priceFeed,
        address _liquidityManager,
        address _liquidityCollector
    ) Ownable(msg.sender) {
        token = ICustomERC20(_token);
        feeCollector = _feeCollector;
        liquidityManager = _liquidityManager;
        liquidityCollector = _liquidityCollector;
        priceFeed = AggregatorV3Interface(_priceFeed);

        totalSupplyTokens = TOTAL_TOKENS;
        updateBeraPrice();
    }

    function updateBeraPrice() public {
        if (block.timestamp >= lastUpdateTime + UPDATE_INTERVAL) {
            (, int256 price,,,) = priceFeed.latestRoundData();
            require(price > 0, "Invalid BERA price");
            // Convert aggregator price to 18 decimals (e.g. if aggregator has 8 decimals)
            lastBeraPrice = uint256(price) * 1e10;
            lastUpdateTime = block.timestamp;
        }
    }

    function getBeraPrice() public view returns (uint256) {
        if (block.timestamp >= lastUpdateTime + UPDATE_INTERVAL) {
            (, int256 freshPrice,,,) = priceFeed.latestRoundData();
            require(freshPrice > 0, "Invalid BERA price");
            return uint256(freshPrice) * 1e10;
        }
        return lastBeraPrice;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 beraPrice = getBeraPrice();

        // Calculate the initial price if nothing has been sold yet
        uint256 initPrice = (INITIAL_PRICE_MULTIPLIER * beraPrice) / (3000 * 1e18);

        if (totalSupplyTokens == TOTAL_TOKENS) {
            // If no tokens are sold, just return the initial price
            return initPrice;
        }

        uint256 sold = TOTAL_TOKENS - totalSupplyTokens;
        uint256 finalPrice = (FINAL_PRICE_MULTIPLIER * beraPrice) / (3000 * 1e18);
        uint256 priceDiff = finalPrice - initPrice;
        return initPrice + (priceDiff * sold) / TOKEN_SOLD_THRESHOLD;
    }

    function buyTokens(uint256 minTokens) external payable nonReentrant {
        require(msg.value > 0, "Zero BERA amount");
        require(totalSupplyTokens > 0, "No tokens available");
        updateBeraPrice();

        uint256 usdValue = (msg.value * getBeraPrice()) / 1e18;
        uint256 price = getCurrentPrice();

        // tokens = (usdValue * PRICE_DECIMALS) / price
        uint256 tokensToMint = (usdValue * PRICE_DECIMALS) / price;
        require(tokensToMint >= minTokens, "Slippage: Not enough tokens");
        require(tokensToMint <= totalSupplyTokens, "Not enough tokens in supply");

        // Collect fee
        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        (bool feeSent,) = feeCollector.call{value: fee}("");
        require(feeSent, "Fee transfer failed");

        // Mint tokens
        token.mint(msg.sender, tokensToMint);
        totalSupplyTokens -= tokensToMint;
        collectedBeraUSD += usdValue;

        // Check if we can deploy liquidity
        bool reachedCap = collectedBeraUSD >= (BERA_RAISED_THRESHOLD * getBeraPrice()) / 1e18
            && (TOTAL_TOKENS - totalSupplyTokens) >= TOKEN_SOLD_THRESHOLD;

        if (!liquidityDeployed && reachedCap) {
            _deployLiquidity();
        }

        emit TokensPurchased(msg.sender, tokensToMint, msg.value);
    }

    function getSellPrice(uint256 tokenAmount) public view returns (uint256) {
        require(tokenAmount > 0, "Zero token amount");
        uint256 price = getCurrentPrice();
        // USD = (tokenAmount * price) / PRICE_DECIMALS
        uint256 usdValue = (tokenAmount * price) / PRICE_DECIMALS;
        // BERA = (usdValue * 1e18) / getBeraPrice()
        return (usdValue * 1e18) / getBeraPrice();
    }

    function sellTokens(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Zero token amount");
        uint256 beraAmount = getSellPrice(tokenAmount);
        require(beraAmount <= address(this).balance, "Insufficient BERA in contract");

        // Burn tokens from the user
        token.burn(msg.sender, tokenAmount);
        totalSupplyTokens += tokenAmount;

        // Collect fee
        uint256 fee = (beraAmount * FEE_PERCENT) / 100;
        uint256 netAmount = beraAmount - fee;
        (bool feeSent,) = feeCollector.call{value: fee}("");
        require(feeSent, "Fee transfer failed");

        // Send remainder to seller
        (bool sellerPaid,) = payable(msg.sender).call{value: netAmount}("");
        require(sellerPaid, "BERA transfer failed");

        emit TokensSold(msg.sender, tokenAmount, beraAmount);
    }

    function _deployLiquidity() internal {
        require(!liquidityDeployed, "Already deployed");
        require(address(this).balance >= 6 ether, "Not enough BERA in contract");

        // We'll deposit 5 BERA and keep 1 for the feeCollector or overhead
        uint256 tokenAmount = 200_000_000 * 1e18; // 200M tokens

        // Mint tokens for liquidity
        token.mint(address(this), tokenAmount);

        // Approve BexLiquidityManager
        token.approve(liquidityManager, tokenAmount);

        // Deploy 5 BERA
        IBexLiquidityManager(liquidityManager).deployLiquidity{value: 5 ether}(
            address(token),
            tokenAmount,
            liquidityCollector
        );

        // The leftover 1 BERA is for fees or overhead
        (bool leftoverSent,) = feeCollector.call{value: 1 ether}("");
        require(leftoverSent, "Leftover BERA not sent");

        liquidityDeployed = true;
        emit LiquidityDeployedToBex(6 ether, tokenAmount);
    }

    receive() external payable {}
}