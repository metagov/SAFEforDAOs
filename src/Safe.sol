// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/interfaces/ISafe.sol";

contract Safe is Ownable, ERC20, ISafe {
    address safeAddress;
    uint constant PRECISION = 3;
    mapping(address => uint256) approvedInvestorInvestments;

    struct SafeCapTable {
        address[] investors;
        mapping(address => uint16) shareholderPercentages;
        uint256 totalInvested;
        uint256 valuation;
    }

    struct CapitalizationTable {
        uint256 numShares;
        address[] investors;
        mapping(address => uint16) shareholderPercentages;
        uint256 valuation;
    }

    SafeCapTable safeCapTable;
    CapitalizationTable capTable;

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
        capTable.numShares = totalSupply();
        safeCapTable.valuation = 0;
        // The founders own 100% of the company at the start; percentages have one decimal point; the below value is interpreted as 100.0%
        safeCapTable.shareholders[msg.sender] = 1000;
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

    // All investors MUST be approved
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
        uint8 percentage = uint16(cash / postMoneyValuation);
        // rebalance cap table and set new valuation
        // safeCapTable.shareholderPercentages[_owner] -= percentage;
        safeCapTable.shareholderPercentages[investor] = percentage;
        safeCapTable.totalInvested += cash;
        safeCapTable.valuation = postMoneyValuation;

        emit NewMoney(investor, cash, percentage, block.timestamp);
    }

    // TODO: Redo logic with new cap table logic
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

    function addOptions(uint16 options) external onlyOwner {
        require(options < 1000, "cannot exceed 100%");
        safeCapTable.shareholderPercentages[_owner] -= options;
        safeCapTable.shareholderPercentages[address(this)] += options;
    }

    function getValuation() external view override returns (uint256) {
        return safeCapTable.valuation;
    }


    // This function is when the shares convert and a new round is initiated. Must be sure to increase options before calling
    // this if necessary
    function startPricedRound(address[] calldata investors, uint256 postMoneyValuation)
        external
        override
        onlyOwner
    {
        // get total dilution to founders and options
        uint256 memory totalDilution = safeCapTable.totalInvested / safeCapTable.valuation;
        // get the dilution percentage
        totalDilution = totalDilution / 100;
        // dilute founders
        safeCapTable.shareholderPercentages[_owner] = totalDilution * safeCapTable.shareholderPercentages[_owner];
        // dilute options
        safeCapTable.shareholderPercentages[address(this)] = totalDilution * safeCapTable.shareholderPercentages[address(this)];
        // calculate new number of shares: totalShares / dilution %
        // TODO: fix this to get the decimals right
        uint256 memory newNumberShares = capTable.numShares / totalDilution;
        // convert SAFE shares: safePercentage * newShares
        // convert option shares: optionPercentage * newShares
        // recalculate _owner shares
        // calculate price per share
        // totalraise from postMoney - this.getValuation 
        // check list of seriesA investors to make sure they are approved, then calculate their ownership by investment / price per share
        // mint new shares for each owner
        // verify and transfer shares something like:
        // uint256 shares = (safeCapTable.numShares * percentage) / 100;
        // _approve(_owner, address(this), shares);
        // _transferFrom(_owner, investor, shares);

    }

    function percent(uint numerator, uint denominator) internal returns(uint16 quotient) {

         // caution, check safe-to-multiply here
        uint _numerator  = numerator * 10 ** (PRECISION+1);
        // with rounding of last digit
        uint _quotient =  ((_numerator / denominator) + 5) / 10;
        return ( uint16(_quotient));
  }

    //safeconversion function?

    fallback() external payable {
        safeCapTable.valuation += msg.value;
    }
}
