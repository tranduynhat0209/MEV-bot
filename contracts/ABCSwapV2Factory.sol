//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import './interfaces/IABCSwapV2Factory.sol';
import './ABCSwapV2Pair.sol';

contract ABCSwapV2Factory {

    address[] public allPairs;
    mapping(address => mapping(address => address)) public pairs;

    event PairCreated(address indexed token0, address indexed token1, address pair);

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Identical Tokens Access');
        (address tokenX, address tokenY) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(tokenA != address(0), 'Zero Address');

        require(pairs[tokenX][tokenY] == address(0), 'Pair already exists'); 

        address pair ;
        bytes memory bytecode = type(ABCSwapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenX, tokenY));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IABCSwapV2Pair(pair).initialize(tokenX, tokenY);
        pairs[tokenX][tokenY] = pair;
        pairs[tokenY][tokenX] = pair; 
        allPairs.push(pair);
        emit PairCreated(tokenX, tokenY, pair);
    }


    function getPair(address tokenA, address tokenB) public view returns(address){
        return pairs[tokenA][tokenB];
    }

    function totalPairs() public view returns(uint256){
        return allPairs.length;
    }
}
