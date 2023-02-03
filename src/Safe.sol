// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/interfaces/ISafe.sol";

contract Safe is Ownable, ERC20, ISafe {
    address safeAddress;
    mapping(address => uint256) approvedInvestorInvestments;

    struct CapTable {
        uint256 numShares;
        address[] investors;
        mapping(address => uint8) shareholderPercentages;
        uint256 valuation;
    }

    CapTable safeCapTable;

    struct EquityFinancing {
        uint256 ask;
        uint256 preMoneyValuation;
        uint256 postMoneyValuation;
        mapping(address => uint256) investorShares;
    }

    constructor() {
        safeAddress = address(0xdead);
    }

    function initialize(address _safeAddress, uint256 _numShares)
        external
        override
    {
        require(safeAddress != 0, "Safe already initialized");
        safeAddress = _safeAddress;
        _mint(safeAddress, _numShares);
        // @audit will this set the owner of the template to msg.sender or the proxy?
        _owner = msg.sender;
        safeCapTable.numShares = totalSupply();
        safeCapTable.valuation = 0;
        // The founders own 100% of the company at the start
        safeCapTable.shareholders[msg.sender] = 100;
    }

    function triggerInvestment(
        address investor,
        uint256 amount,
        uint256 postMoneyValuation
    ) external override {
        require(
            safeAddress == msg.sender,
            "Only the safe can trigger an investment"
        );
        require(
            approvedInvestorInvestments[investor],
            "Investor must be approved"
        );
        require(
            approvedInvestorInvestments[investor] == amount,
            "Investor must be approved for this amount"
        );
        newSAFEMoney(investor, amount, postMoneyValuation);
    }

    function approveInvestor(address investor, uint256 investment)
        public
        onlyOwner
    {
        approvedInvestorInvestments[investor] = investment;
    }

    /**
     * @dev Used to add a new investor to the cap table and calculate the percentage of the company they own & new valuation.
     * @note this function should only be used in a SAFE investment, not an equity financing round where new shares are added to the total.
     */
    function newSAFEMoney(
        address investor,
        uint256 cash,
        uint256 postMoneyValuation
    ) internal returns (uint256) {
        require(cash > 0, "Cash must be greater than 0");
        require(
            safeCapTable.shareholderPercentages[investor] == 0,
            "Investor already exists in cap table"
        );
        safeCapTable.investors.push(investor);
        uint8 percentage = uint8(cash / postMoneyValuation);
        // rebalance cap table and set new valuation
        safeCapTable.shareholderPercentages[_owner] -= percentage;
        safeCapTable.shareholderPercentages[investor] = percentage;
        safeCapTable.valuation = postMoneyValuation;

        emit NewMoney(investor, cash, percentage, block.timestamp);
    }

    function dissolution() external override onlyOwner returns (bool) {
        for (uint256 i = 0; i < safeCapTable.investors.length; i++) {
            address investor = safeCapTable.investors[i];
            uint256 shares = balanceOf(investor);
            uint256 cash = (shares * safeCapTable.valuation) /
                safeCapTable.numShares;
            _approve(investor, address(this), shares);
            _transferFrom(investor, _owner, shares);
            // @note: this should be a trigger to transfer the cash to the investor
            payable(investor).transfer(cash);
            safeCapTable.valuation -= cash;
        }
        require(
            balanceOf(_owner) == safeCapTable.numShares,
            "Not all shares were returned to the owner"
        );
        return true;
    }

    function addOptions(uint8 options) external onlyOwner {
        safeCapTable.shareholderPercentages[_owner] -= options;
        safeCapTable.shareholderPercentages[address(this)] += options;
    }

    function getValuation() external view override returns (uint256) {
        return safeCapTable.valuation;
    }


    // This function is when the shares convert and a new round is initiated
    function startPricedRound(uint256 ask, address[] calldata investors, uint256 preMoneyValuation)
        external
        override
        onlyOwner
    {
        // convert SAFE shares
        // Add list of investors to the global investor list
        // totalraise
        // mint new shares = investment amount / price per share
        // calculate and transfer shares
        // uint256 shares = (safeCapTable.numShares * percentage) / 100;
        // _approve(_owner, address(this), shares);
        // _transferFrom(_owner, investor, shares);

    }

    //safeconversion function

    fallback() external payable {
        safeCapTable.valuation += msg.value;
    }
}
