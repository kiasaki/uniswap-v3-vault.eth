//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

contract Vault is ERC20, Initializable {
    using SafeERC20 for IERC20;

    address private _name;
    address private _symbol;
    IERC20 public token0;
    IERC20 public token1;
    int24 public fee;
    int24 public tickLower;
    int24 public tickUpper;
    uint public feeEntry;
    uint public feeExit;
    uint public feeCarry;
    address public feeAddress;
    address public owner;
    mapping(address => bool) public keepers;
    bool collectOnWithdraw;

    IUniswapV3Pool pool;
    bool poolEnabled;
    uint128 poolLiquidity;
    uint256 lastCollectFees;
    mapping(uint => bool) depositBlocks;

    function initializeLock() external initializer {}

    function initialize(
        string calldata name,
        string calldata symbol,
        address _token0,
        address _token1,
        int24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
        uint _feeEntry,
        uint _feeExit,
        uint _feeCarry,
        address _feeAddress,
        address _owner,
        address[] calldata _keepers,
        bool _collectOnWithdraw
    ) external initializer {
        _name = name;
        _symbol = symbol;
        fee = _fee;
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        feeEntry = _feeEntry;
        feeExit = _feeExit;
        feeCarry = _feeCarry;
        feeAddress = _feeAddress;
        owner = _owner;
        for (uint i = 0; i < _keepers.length; i++) {
          keepers[_keepers[i]] = true;
        }
        collectOnWithdraw = _collectOnWithdraw;

        poolEnabled = true;
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: tokenA, token1: tokenB, fee: fee});
        token0 = IERC20(poolKey.token0);
        token1 = IERC20(poolKey.token1);
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
    }

    modifier onlyOwner {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyOwnerOrKeeper {
        require(msg.sender == owner || keepers[msg.sender], "!ownerOrKeeper");
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setKeeper(address _keeper, bool _enabled) external onlyOwner {
        keepers[_keeper] = _enabled;
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    function setCollectOnWithdraw(bool _collectOnWithdraw) external onlyOwner {
        collectOnWithdraw = _collectOnWithdraw;
    }

    function setFees(uint entry, uint exit, uint carry) external onlyOwnerOrKeeper {
        feeEntry = entry;
        feeExit = exit;
        feeCarry = carry;
    }

    function rebalance(
        bool enabled,
        int24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
    ) external onlyOwnerOrKeeper {
        // burn 100% of the liquidity
        pool.burn(
            tickLower,
            tickUpper,
            type(uint128).max
        );
        (fee0, fee1) = pool.collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
        uint fee0Share = (fee0 * feeCarry) / 1e18;
        if (fee0Share > 0) token0.safeTransfer(feeAddress, fee0Share);
        uint fee1Share = (fee1 * feeCarry) / 1e18;
        if (fee1Share > 0) token1.safeTransfer(feeAddress, fee1Share);

        poolEnabled = enabled;
        fee = _fee;
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        if (poolEnabled) {
            poolLiquidity = _poolDeposit(
                token0.balanceOf(address(this)),
                token1.balanceOf(address(this))
            );
        }
    }

    function deposit(uint128 amount0, uint128 amount1) external {
				depositBlocks[block.number] = true;
        require(poolEnabled, "disabled");
        (, int24 tick, , , , , ) = pool.slot0();
        require(tick < tickLower || tick > tickUpper, "out of range");
        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);

        // Pay entry fee
        uint fee0 = (amount0 * feeEntry) / 1e18;
        if (fee0 > 0) token0.safeTransfer(feeAddress, fee0);
        uint fee1 = (amount1 * feeEntry) / 1e18;
        if (fee1 > 0) token1.safeTransfer(feeAddress, fee1);

        uint128 poolLiquidityBefore = poolLiquidity;
        poolLiquidity = _poolDeposit(amount0 - fee0, amount1 - fee1);
        uint128 poolLiquidityAdded = poolLiquidityBefore - poolLiquidity;

        // Mint 1:1 when first person in, else calculation ratio ownership
        if (totalSupply() == 0 || pooLiquidityBefore == 0) {
          _mint(msg.sender, poolLiquidity);
        } else {
          _mint(msg.sender, (poolLiquidityAdded * totalSupply()) / poolLiquidityBefore;
        }
    }

    function withdraw(uint amount) external {
        require(depositBlocks[block.number], "no withdraw in deposit block");
        if (collectOnWithdraw && poolEnabled) {
            collectFees();
        }
        uint totalSupplyBefore = totalSupply();
        uint owedLiquidity = (amount * poolLiquidity) / totalSupplyBefore;
        _burn(msg.sender, amount);
        uint amount0;
        uint amount1;
        if (poolEnabled) {
            (amount0, amount1) = pool.burn(tickLower, tickUpper, owedLiquidity);
        } else {
            amount0 = token0.balanceOf(address(this)) * amount / totalSupplyBefore;
            amount1 = token1.balanceOf(address(this)) * amount / totalSupplyBefore;
        }

        // Pay exit fee
        uint fee0 = (amount0 * feeExit) / 1e18;
        if (fee0 > 0) token0.safeTransfer(feeAddress, fee0);
        uint fee1 = (amount1 * feeExit) / 1e18;
        if (fee1 > 0) token1.safeTransfer(feeAddress, fee1);

        token0.safeTransfer(msg.sender, amount0 - fee0);
        token0.safeTransfer(msg.sender, amount1 - fee1);
		}

    function collectFees() external {
        require(poolEnabled, "disabled");
        if (lastCollectFees + 1 hour > block.timestamp) return;

        // Update fee growth for our position
        pool.burn(tickLower, tickUpper, 0);

        // Collect fees back to vault
        (fee0, fee1) = pool.collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        // Pay carry fee
        uint fee0Share = (fee0 * feeCarry) / 1e18;
        if (fee0Share > 0) token0.safeTransfer(feeAddress, fee0Share);
        uint fee1Share = (fee1 * feeCarry) / 1e18;
        if (fee1Share > 0) token1.safeTransfer(feeAddress, fee1Share);
        
        // Compond fees back into pool
        poolLiquidity = _poolDeposit(fee0 - fee0Share, fee1 - fee1Share);
    }

    function _poolDeposit(uint128 amount0, uint128 amount1) internal returns (uint128 liquidity) {
        // calculate liquidity from amount0 and amount1
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount0,
                amount1
            );
        }
        pool.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            0x
        );
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        require(msg.sender == pool, "callback not from pool");
        if (amount0Owed > 0) token0.safeTransfer(address(pool), amount0Owed);
        if (amount1Owed > 0) token1.safeTransfer(address(pool), amount1Owed);
    }
}
