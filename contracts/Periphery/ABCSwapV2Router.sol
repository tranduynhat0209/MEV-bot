// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IERC20} from "../interfaces/IERC20.sol";
import {ABCSwapV2Library} from "./libraries/ABCSwapV2Library.sol";
import {IABCSwapV2Factory} from "../interfaces/IABCSwapV2Factory.sol";
import {IABCSwapV2Pair} from "../interfaces/IABCSwapV2Pair.sol";

contract ABCSwapV2Router {

    IABCSwapV2Factory public factory;

    constructor(address _factory) {
        factory = IABCSwapV2Factory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountAdesired,
        uint256 amountBdesired,
        uint256 amountAmin,
        uint256 amountBmin,
        address to
        ) public
        returns(
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity){

        if (factory.getPair(tokenA, tokenB) == address(0)){
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = calculateLiquidity(
            tokenA, 
            tokenB, 
            amountAdesired, 
            amountBdesired, 
            amountAmin, 
            amountBmin
        );

        address pair = ABCSwapV2Library.pairFor(address(factory), tokenA, tokenB);

        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = IABCSwapV2Pair(pair).mint(to);
    }

    function removeLiquidity(
            address tokenA,
            address tokenB,
            uint256 liquidity,
            uint256 amountAmin,
            uint256 amountBmin,
            address to
        ) public {
        require(IABCSwapV2Factory(factory).getPair(tokenA, tokenB) != address(0), "Tokens pair not exists");

        address pair = ABCSwapV2Library.pairFor(address(factory), tokenA, tokenB);
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amountA, uint256 amountB) = IABCSwapV2Pair(pair).burn(to);

        require(amountA >= amountAmin && amountB >= amountBmin, "Insufficient Amounts");
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = ABCSwapV2Library.getAmountsOut(
            address(factory),
            amountIn,
            path
        );
        require(amounts[amounts.length - 1] > amountOutMin, "Insufficient OutputAmount");
        _safeTransferFrom(
            path[0],
            msg.sender,
            ABCSwapV2Library.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = ABCSwapV2Library.getAmountsIn(
            address(factory),
            amountOut,
            path
        );
        require(amounts[amounts.length - 1] < amountInMax, "Excessive InputAmount");
        _safeTransferFrom(
            path[0],
            msg.sender,
            ABCSwapV2Library.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to_
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address tokenX, ) = ABCSwapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amountXout, uint256 amountYout) = input == tokenX
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? ABCSwapV2Library.pairFor(
                    address(factory),
                    output,
                    path[i + 2]
                )
                : to_;
            IABCSwapV2Pair(
                ABCSwapV2Library.pairFor(address(factory), input, output)
            ).swap(to, amountXout, amountYout, "");
        }
    }

    function calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountAdesired,
        uint256 amountBdesired,
        uint256 amountAmin,
        uint256 amountBmin
        ) internal returns(uint256 amountA, uint256 amountB){
            (uint256 reserveA, uint256 reserveB) = ABCSwapV2Library.getReserves(address(factory), tokenA, tokenB);
            if(reserveA == 0 && reserveB == 0){
                (amountA, amountB) = (amountAdesired, amountBdesired);
            } else {
                uint256 amountBoptimal = ABCSwapV2Library.qoute(amountAdesired, reserveA, reserveB);
                if(amountBoptimal <= amountBdesired){
                    require(amountBoptimal > amountBmin, "Insufficient Amount");
                    (amountA, amountB) = (amountAdesired, amountBoptimal);
                } else {
                    uint256 amountAoptimal = ABCSwapV2Library.qoute(amountBdesired, reserveB, reserveA);
                    require(amountAoptimal <= amountAdesired);
                    require(amountAoptimal > amountAmin, "Insufficient Amount");
                    (amountA, amountB) = (amountAoptimal, amountBdesired);
                }
            }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Transfer Failed');
    }

}