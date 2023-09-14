pragma solidity 0.8.17;

import './interface/DepositContract.sol';

import "./interface/IInsurance.sol";

contract StakingPool {
  enum State {
    Pending,
    FundRaising,
    Validating,
    WithdrawOpen
  }

  uint256 public constant MAX_SECONDS_IN_EXIT_QUEUE = 12 weeks;
  uint256 public constant COMMISSION_RATE_SCALE = 10000;
  IDepositContract public constant depositContract =
    IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa);

  State public state;
  address public operator;
  address public insurance;
  uint256 public totalDeposit;
  mapping(address => uint256) public deposits;

  // Validator related
  bytes public pubkey;
  bytes public signature;
  bytes32 public depositDataRoot;

  // Service related
  uint256 public exitDate;
  uint256 public commissionRate;

  event Deposit(address depositor, uint256 value);
  event Withdrawal(address depositor, uint256 shareAmount, uint256 value);
  event ValidatorCreation(bytes pubkey);
  event ServiceEnd();

  modifier onlyOperator() {
    require(msg.sender == operator, "Only operator");
    _;
  }

  constructor(address _operator, address _insurance) {
    operator = _operator;
    insurance = _insurance;
  }

  receive() external payable {}

  function submitOperatorData(
    bytes calldata _pubkey,
    bytes calldata _signature,
    bytes32 _depositDataRoot,
    uint256 _exitDate,
    uint256 _commissionRate
  ) external onlyOperator {
    require(state == State.Pending);

    pubkey = _pubkey;
    signature = _signature;
    depositDataRoot = _depositDataRoot;
    exitDate = _exitDate;
    commissionRate = _commissionRate;
    state = State.FundRaising; 
  }

  function registerInsurance() external {
    require(state == State.FundRaising);

    if (insurance != address(0)) {
      IInsurance(insurance).registerContract();
    }
  }

  function createValidator() external {
    require(state == State.FundRaising);

    state = State.Validating;

    depositContract.deposit{value: 32 ether}(
      pubkey,
      abi.encodePacked(uint96(0x100000000000000000000000), address(this)),
      signature,
      depositDataRoot
    );

    emit ValidatorCreation(pubkey);
  }

  function deposit() external payable returns (uint256 depositValue) {
    require(state == State.FundRaising, "Not in fund raising state");

    uint256 surplus = (address(this).balance > 32 ether) ?
      (address(this).balance - 32 ether) : 0;

    depositValue = msg.value - surplus;
    deposits[msg.sender] += depositValue;
    totalDeposit += depositValue;

    if (surplus > 0)
      msg.sender.call{value: surplus}("");

    emit Deposit(msg.sender, depositValue);
  }

  // This function should only be called after the validator is exited and
  // validator balance is withdrawn to the contract, otherwise the contract will
  // handle it as if a loss has been incurred.
  function endOperatorService() external {
    require(state == State.Validating, "Only in validating state");
    require(
      (msg.sender == operator && block.timestamp > exitDate) ||
      (deposits[msg.sender] > 0 && block.timestamp > exitDate + MAX_SECONDS_IN_EXIT_QUEUE),
      "Permission denied or wrong time"
    );

    state = State.WithdrawOpen;

    uint256 balance = address(this).balance;
    if (balance > 32 ether) {
      uint256 profit = balance - 32 ether;
      uint256 commission = profit * commissionRate / COMMISSION_RATE_SCALE;
      payable(operator).call{value: commission}("");  
    } else {
      uint256 shortfall = 32 ether - balance;
      if (insurance != address(0)) {
        IInsurance(insurance).requestCompensation(shortfall);
      }
    }

    if (insurance != address(0)) {
      IInsurance(insurance).unregisterContract();
    }

    emit ServiceEnd();
  }

  function withdraw(uint256 shareAmount) external returns (uint256 value) {
    require(state != State.Validating, "Can't withdraw in validating state");

    value = shareAmount * address(this).balance / totalDeposit;
    deposits[msg.sender] -= shareAmount;
    totalDeposit -= shareAmount;
    
    (bool success, ) = msg.sender.call{value: value}("");
    require(success, "Transfer failed");

    emit Withdrawal(msg.sender, shareAmount, value);
  }
}
