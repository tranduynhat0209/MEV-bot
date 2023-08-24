//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import './interfaces/IABCSwapV2Pair.sol';
import './ABCSwapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
//import './interfaces/IERC20.sol';
import './interfaces/IABCSwapV2Factory.sol';
import './interfaces/IABCSwapV2Callee.sol';

contract ABCSwapV2Pair is ABCSwapV2 {

    using SafeMath  for uint256;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public tokenX;
    address public tokenY;

    uint112 private reserveX;
    uint112 private reserveY;           
    uint32  private blockTimestampLast; 

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast;

    bool private lock ;


    modifier reentrancyLock() {
        require(lock== false, 'LOCKED');
        lock = true;
        _;
        lock = false;
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address Swapper, uint256 AmountAout, uint256 AmountBout, address to);
    event Sync(uint112 reserve0, uint112 reserve1);

    function initialize(address _tokenX, address _tokenY) external {
        require(msg.sender == factory, 'ABCSwapV2: Only admin'); 
        tokenX = _tokenX;
        tokenY = _tokenY;
    }



    function getReserves() public view returns (uint112 , uint112 , uint32 ) {
        return (reserveX, reserveY, blockTimestampLast);
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ABCSwapV2: TRANSFER_FAILED');
    }

    

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'Overflow');
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserveX = uint112(balance0);
        reserveY = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserveX, reserveY);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external reentrancyLock returns (uint liquidity) {
        
        (uint112 _reserveX, uint112 _reserveY, ) = getReserves();

        uint balanceX = IERC20(tokenX).balanceOf(address(this));
        uint balanceY = IERC20(tokenY).balanceOf(address(this));

        uint amountX = balanceX.sub(_reserveX);
        uint amountY = balanceY.sub(_reserveY);

        //bool feeOn = _mintFee(_reserve0, _reserve1);

        uint _totalSupply = totalSupply(); 

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountX.mul(amountY)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); 
        } else {
            liquidity = Math.min(amountX.mul(_totalSupply) / _reserveX, amountY.mul(_totalSupply) / _reserveY);
        }

        require(liquidity > 0, 'ABCSwapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balanceX, balanceY, _reserveX, _reserveY);
        //if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amountX, amountY);
        return liquidity;
    }

    function burn(address to) external reentrancyLock returns (uint amountX, uint amountY) {

        (uint112 _reserveX, uint112 _reserveY,) = getReserves(); 
        address _tokenX = tokenX;                                
        address _tokenY = tokenY;                                
        uint balanceX = IERC20(_tokenX).balanceOf(address(this));
        uint balanceY = IERC20(_tokenY).balanceOf(address(this));

        uint liquidity = balanceOf(address(this));

        uint _totalSupply = totalSupply(); 
        amountX = liquidity.mul(balanceX) / _totalSupply; 
        amountY = liquidity.mul(balanceY) / _totalSupply; 
        require(amountX > 0 && amountY > 0, 'Insufficient Liquidity Burned');

        _burn(address(this), liquidity);

        _safeTransfer(_tokenX, to, amountX);
        _safeTransfer(_tokenY, to, amountY);

        balanceX = IERC20(_tokenX).balanceOf(address(this));
        balanceY = IERC20(_tokenY).balanceOf(address(this));

        _update(balanceX, balanceY , _reserveX, _reserveY);

        emit Burn(msg.sender, amountX, amountY, to);

        return (amountX, amountY);
    }

    function swap(uint256 amountXOut, uint256 amountYOut, address to, bytes calldata data) external reentrancyLock {
        require(amountXOut > 0 || amountYOut > 0, 'Insufficient OutputAmount');

        (uint112 _reserveX, uint112 _reserveY,) = getReserves(); 
        require(amountXOut < _reserveX && amountYOut < _reserveY, 'Insufficient OutputAmount');

        //address _tokenX = tokenX;
        //address _tokenY = tokenY;

        if (amountXOut > 0) _safeTransfer(tokenX, to, amountXOut); 
        if (amountYOut > 0) _safeTransfer(tokenY, to, amountYOut); 

        if (data.length > 0) IABCSwapV2Callee(to).ABCSwapV2Call(msg.sender, amountXOut, amountYOut, data);

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        
        uint amountXIn = balanceX > _reserveX - amountXOut ? balanceX - (_reserveX - amountXOut) : 0;
        uint amountYIn = balanceY > _reserveY - amountYOut ? balanceY - (_reserveY - amountYOut) : 0;
        require(amountXIn > 0 || amountYIn > 0, 'Insufficient InputAmount');

       
        uint balanceXAdjusted = balanceX.mul(1000).sub(amountXIn.mul(3));
        uint balanceYAdjusted = balanceY.mul(1000).sub(amountYIn.mul(3));


        require(balanceXAdjusted.mul(balanceYAdjusted) >= uint(_reserveX).mul(_reserveY).mul(1000**2), ' InvaludDK ');

        _update(balanceX, balanceY, _reserveX, _reserveY);
        emit Swap(msg.sender, amountXOut, amountYOut, to);
    }

    // force balances to match reserves
    function skim(address to) external reentrancyLock {
        address _tokenX = tokenX; // gas savings
        address _tokenY = tokenY; // gas savings
        _safeTransfer(_tokenX, to, IERC20(_tokenX).balanceOf(address(this)).sub(reserveX));
        _safeTransfer(_tokenY, to, IERC20(_tokenY).balanceOf(address(this)).sub(reserveY));
    }

    // force reserves to match balances
    function sync() external reentrancyLock {
        _update(IERC20(tokenX).balanceOf(address(this)), IERC20(tokenY).balanceOf(address(this)), reserveX, reserveY);
    }
}
