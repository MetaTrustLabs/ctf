pragma solidity 0.8.17;

interface IInsurance {
    function registerContract() external;
    function unregisterContract() external;
    function requestCompensation(uint256 shortfall) external;
    function withdraw() external;
}
