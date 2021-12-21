//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "./Vault.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Factory is Clones {
    event Created(address indexed contractAddress);

    address masterContract;

    constructor(address _masterContract) {
        masterContract = _masterContract;
    }

    function create(
        string calldata name,
        string calldata symbol,
        address tokenA,
        address tokenB,
        int24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint feeEntry,
        uint feeExit,
        uint feeCarry,
        address feeAddress,
        address owner,
        address[] calldata keepers,
        bool collectOnWithdraw
    ) external returns (address) {
        Vault vault = Vault(clone(masterContract));
        vault.initialize(
          name,
          symbol,
          tokenA,
          tokenB,
          fee,
          tickLower,
          tickUpper,
          feeEntry,
          feeExit,
          feeCarry,
          feeAddress,
          owner,
          keepers,
          collectOnWithdraw
        );
        emit Created(address(vault));
        return address(vault);
    }
}
