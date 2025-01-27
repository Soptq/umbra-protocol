// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/interface/IUmbra.sol";

contract UmbraBatchSend {
  IUmbra internal immutable umbra;

  /// @param amount Amount of ETH to send per address excluding the toll
  struct SendEth {
    address payable receiver;
    uint256 amount;
    bytes32 pkx;
    bytes32 ciphertext;
  }

  struct SendToken {
    address receiver;
    address tokenAddr;
    uint256 amount;
    bytes32 pkx;
    bytes32 ciphertext;
  }

  error ValueMismatch();
  event BatchSendExecuted(address indexed sender);

  constructor(IUmbra _umbra) {
    umbra = _umbra;
  }

  function batchSendEth(uint256 _tollCommitment, SendEth[] calldata _params) external payable {
    if(msg.value != _sumValueFromEthSends(_tollCommitment, _params)) revert ValueMismatch();
    _batchSendEth(_tollCommitment, _params);
    emit BatchSendExecuted(msg.sender);
  }

  function batchSendTokens(uint256 _tollCommitment, SendToken[] calldata _params) external payable {
    if(msg.value != _tollCommitment * _params.length) revert ValueMismatch();
    _batchSendTokens(_tollCommitment, _params);
    emit BatchSendExecuted(msg.sender);
  }

  function batchSend(
    uint256 _tollCommitment,
    SendEth[] calldata _ethParams,
    SendToken[] calldata _tokenParams
  ) external payable {
    uint256 _totalAmount = _sumValueFromEthSends(_tollCommitment, _ethParams) + (_tollCommitment * _tokenParams.length);
    if(msg.value != _totalAmount) revert ValueMismatch();

    _batchSendEth(_tollCommitment, _ethParams);
    _batchSendTokens(_tollCommitment, _tokenParams);
    emit BatchSendExecuted(msg.sender);
  }

  function _batchSendEth(uint256 _tollCommitment, SendEth[] calldata _params) internal {
    for (uint256 i = 0; i < _params.length; i++) {
      umbra.sendEth{value: _params[i].amount + _tollCommitment}(_params[i].receiver, _tollCommitment, _params[i].pkx, _params[i].ciphertext);
    }
  }

  function _batchSendTokens(uint256 _tollCommitment, SendToken[] calldata _params) internal {
    for (uint256 i = 0; i < _params.length; i++) {
      IERC20 token = IERC20(address(_params[i].tokenAddr));

      SafeERC20.safeTransferFrom(token, msg.sender, address(this), _params[i].amount);

      if (token.allowance(address(this), address(umbra)) == 0) {
        SafeERC20.safeApprove(token, address(umbra), type(uint256).max);
      }

      umbra.sendToken{value: _tollCommitment}(
        _params[i].receiver,
        _params[i].tokenAddr,
        _params[i].amount,
        _params[i].pkx,
        _params[i].ciphertext
      );
    }
  }

  function _sumValueFromEthSends(uint256 _tollCommitment, SendEth[] calldata _params) internal pure returns(uint256 valueSentAccumulator) {
    for (uint256 i = 0; i < _params.length; i++) {
      //amount to be sent per receiver
      valueSentAccumulator = valueSentAccumulator + _params[i].amount + _tollCommitment;
    }
  }

}
