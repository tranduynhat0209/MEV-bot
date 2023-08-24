pragma solidity >=0.8.10;

interface IABCSwapV2Callee {
    function ABCSwapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
