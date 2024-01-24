// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./tokens/ERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapFactory.sol";
import "./interfaces/IUniswapExchange.sol";
import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";

contract ZeroSwap {

    // Q Learning Algorithm
    int256 public scalingFactor = 1000000;
    int256[][] public actions;
    int256 public windowSize = 10;
    int256 public alpha = 100000;
    int256 gamma = 990000;
    int256 epsilon = 100000;
    int256[][][] QTable;
    int256[] stateHistory;
    int256 pointer;


    // address public owner;
    // uint256 public totalSupply;
    // string public name;
    // string public symbol;
    // uint8 public decimals;
    // mapping(address => uint256) public balanceOf;
    // mapping(address => mapping(address => uint256)) public allowance;


    // Events
    // event Transfer(address indexed from, address indexed to, uint256 value);

    // event Approval(
    //     address indexed owner,
    //     address indexed spender,
    //     uint256 value
    // );

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function transfer(address _to, uint256 _value)
        external
        returns (bool success)
    {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        success = true;
    }

    function approve(address _spender, uint256 _value)
        external
        returns (bool success)
    {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        success = true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(
            allowance[_from][msg.sender] >= _value,
            "Insufficient allowance"
        );
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        success = true;
    }
}