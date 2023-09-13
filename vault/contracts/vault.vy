# @version 0.3.7
owner: public(address)
solvedFlag: public(bool)
globalRewardRate: public(uint256)
deposits: public(HashMap[address, uint256])
nodeRewardRateBase: public(HashMap[uint256, uint256])
nodes: public(HashMap[address, HashMap[uint256, uint256]])
depositTimes: public(HashMap[address, uint256])
OWNER_PURCHASE_COST: constant(uint256) = 10000000

@external
def isSolved() -> bool:
    return self.solvedFlag

@external
def __init__():
    self.solvedFlag = False
    self.owner = msg.sender

@external
def createMyNode(_nodeId: uint256, _rewardRateBase: uint256,_rewardFactor: uint256):
    self.nodeRewardRateBase[_nodeId] = _rewardRateBase

@internal
def calculateForRewardRate(_rewardRateBase: uint256=1, _multiplicate: uint256=20) -> uint256:
    _result: uint256 = 0
    _multiplicateShift: uint256 = 0
    if _rewardRateBase <= 10:
        if _multiplicate <= 15:
            _multiplicateShift = _multiplicate * 2
        else:
            _multiplicateShift = _multiplicate * 3
        _result = _multiplicateShift * _rewardRateBase
    elif _rewardRateBase > 10 and _rewardRateBase <= 20:
        if _multiplicate > 10 and _multiplicate <= 20:
            _multiplicateShift = _multiplicate * 4
        else:
            _multiplicateShift = _multiplicate * 5
        _result = _multiplicateShift * (_rewardRateBase - 5)
    else:
        if _multiplicate > 20:
            if _multiplicate <= 30:
                _multiplicateShift = _multiplicate * 6
            else:
                _multiplicateShift = _multiplicate * 7
        else:
            _multiplicateShift = _multiplicate * 5
        _result = _multiplicateShift * (_rewardRateBase + 5)
    return _result

@external
def purchaseForOwner():
    assert self.deposits[msg.sender] == OWNER_PURCHASE_COST * block.timestamp
    self.owner = msg.sender
    self.solvedFlag = True
    self.deposits[msg.sender] = 0

@internal
def getNodeRewardBase(_nodeId: uint256) -> uint256:
    return self.nodeRewardRateBase[_nodeId]

@external
@payable
@nonreentrant('lock')
def depositOnce(_nodeId: uint256):
    assert self.depositTimes[msg.sender] == 0
    assert msg.value > 0
    assert self.nodeRewardRateBase[_nodeId] > 0

    self.depositTimes[msg.sender]+=1
    _rewardRate: uint256 = self.calculateForRewardRate(self.getNodeRewardBase(_nodeId))
    _rewardAmount: uint256 = msg.value * _rewardRate * self.balance
    self.nodes[msg.sender][_nodeId] += _rewardAmount
    self.deposits[msg.sender] += _rewardAmount

@external
@nonreentrant('lock')
def emergencyWithdraw(_nodeId: uint256):
    assert self.nodes[msg.sender][_nodeId] > 0
    self.deposits[msg.sender] = 0


