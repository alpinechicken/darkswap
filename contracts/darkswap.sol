pragma solidity ^0.8.7;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

//TODO:
// - Generalize for different decimals
// - Clean up empty addresses

// Darkswap for uniswap pool
contract DarkSwap {
    // Balance data (helps keep track of keys in token0Balances/token1Balances)   
    struct balanceData {
        uint256 balance;
        bool isValue;
    }

    address public token0; // token0 address
    address public token1; // token1 address
    uint24 public fee; // Uniswap pool fee
    mapping (address => balanceData) public token0Balances;
    mapping (address => balanceData) public token1Balances;
    address[] public token0List; // record all unique addresses
    address[] public token1List; // record all unique addresses
    uint256 public token0Sum = 0; // total amount of token 0 in queue
    uint256 public token1Sum = 0; // total amount of token 1 in queue


    constructor(address _token0, address _token1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }

    function deposit(address _tokenAddress, uint256 _amount) public {
        // Deposit tokens to queue
        console.log("token0 amt %s token1 amt %s",IERC20(token0).balanceOf(msg.sender), IERC20(token0).balanceOf(msg.sender));
        require(_tokenAddress == token0 || _tokenAddress == token1, "Token not in this pool" );
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        if (_tokenAddress == token0){
            token0Balances[msg.sender].balance += _amount;
            token0Sum += _amount;
            // keep track of live keys
            if(!token0Balances[msg.sender].isValue){
                token0List.push(msg.sender);
                token0Balances[msg.sender].isValue = true;
            }
        } else if (_tokenAddress == token1) {
            token1Balances[msg.sender].balance += _amount;
            token1Sum += _amount;
            // keep track of live keys
            if(!token1Balances[msg.sender].isValue){
                token1List.push(msg.sender);
                token1Balances[msg.sender].isValue = true;
            }
        }
        
    }

    function withdraw(address _tokenAddress, uint256 _amount) public {
        // Withdraw tokens from queue
        require(_tokenAddress == token0 || _tokenAddress == token1, "Token not in this dark pool" );
        if (_tokenAddress == token0){
            require(token0Balances[msg.sender].balance >= _amount, "Insufficient balance");
            token0Balances[msg.sender].balance -= _amount;
            token0Sum -= _amount;
            IERC20(token0).transfer(msg.sender, _amount);
        } else if (_tokenAddress == token1) {
            require(token1Balances[msg.sender].balance>= _amount, "Insufficient balance");
            token1Balances[msg.sender].balance -= _amount;
            token1Sum -= _amount;
            IERC20(token1).transfer(msg.sender, _amount);
        }
    }

    function swap() public {
        // Execute darkswap
        _swap();
    }

    function _swap() private {
        // Swap at oracle price
        uint256 oraclePrice = 2e18; // mock price = 2 - TODO: exchange this for uniswap price (amount of token0 for one unit of token1)

        uint256 token0Value = token0Sum;
        uint256 token1Value = token1Sum*oraclePrice/1e18;
        console.log("token0Value %s token1Value", token0Value, token1Value);
        if (token0Value>token1Value){
            uint256 valueRatio = (token1Value*1e18/token0Value);
            console.log("value ratio is %s", valueRatio);
            // token0 payers get ratioed
            for (uint i=0;i<token0List.length;i++){
                uint256 amountPay = valueRatio*token0Balances[token0List[i]].balance/1e18
                uint256 amountReceive = 1e18*amountIn/oraclePrice;
                IERC20(token1).transfer(token0List[i], amountReceive);
                token0Balances[token0List[i]].balance -= amountPay;
            }
            for (uint i=0;i<token1List.length;i++){
                uint256 amountPay = token1Balances[token1List[i]].balance
                uint256 amountReceive = amountIn*oraclePrice/1e18;
                IERC20(token0).transfer(token1List[i], amountReceive);
                token1Balances[token1List[i]].balance -= amountPay;

            }                  
        } else if (token1Value>=token0Value) {
            uint256 valueRatio = (token0Value*1e18/token1Value);
            console.log("value ratio is %s", valueRatio);
            //token1 payers ratioed
            for (uint i=0;i<token0List.length;i++){
                uint256 amountPay = token0Balances[token0List[i]].balance
                uint256 amountReceive = 1e18*amountPay/oraclePrice;
                IERC20(token1).transfer(token0List[i], amountOut);
                token0Balances[token0List[i]].balance -= amountPay;
            }
            for (uint i=0;i<token1List.length;i++){
                // Token 1 ratioed swap
                uint256 amountPay = valueRatio*token1Balances[token1List[i]].balance/1e18
                uint256 amountReceive = amountPay*oraclePrice/1e18;
                IERC20(token0).transfer(token1List[i], amountReceive);
                token1Balances[token1List[i]].balance -= amountPay;

            }        
        } 

    } 

}

// Test coins
contract wethToken is ERC20 {
    constructor(uint256 initialSupply) public ERC20("weth", "WETH") {
        _mint(msg.sender, initialSupply);
    }
}

contract usdcToken is ERC20 {
    constructor(uint256 initialSupply) public ERC20("usdc", "USDC") {
        _mint(msg.sender, initialSupply);
    }
}