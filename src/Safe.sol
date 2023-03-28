// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";
contract Safe is Ownable, ERC20 {
    // Global variables
    address safeAddress;
    mapping(address => uint256) approvedInvestorInvestments;

    // Events

    /**
     * @dev Emitted when an investor invests in the SAFE. This event returns a calculated amount (in percentage) of how much
     * equity the investor has acquired.
     *
     * Note: The percentageAcquired is returned as a uint256 that represents the percentage multiplied by 10^18.
     */
    event NewMoney(
        address indexed investor,
        uint256 amount,
        uint256 percentageAcquired,
        uint256 timestamp
    );

    /**
     * @dev Emitted when an investor cashes out their investment. Shares are sent burned as the investor receives their money.
     */
    event CashOut(address indexed investor, uint256 amount);

    // Structs

    /**
     * This is the struct for the SAFE capitalization table.
     */
    struct SafeCapTable {
        address[] investors;
        mapping(address => uint256) shareholderPercentages;
        uint256 totalInvested;
        uint256 valuation;
    }

    struct CapitalizationTable {
        uint256 numShares;
        uint256 pricePerShare;
        address[] investors;
        mapping(address => uint256) shareholderPercentages;
        uint256 valuation;
        uint256 totalInvested;
    }

    SafeCapTable safeCapTable;
    CapitalizationTable capTable;

    // The constructor sets safeAddress to 0xdead, which is an invalid address. This is because this smart contract is merely a template
    // Constructor for the ERC20 token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        safeAddress = address(0xdead);
    }


    // The initialize function is used for clones of the template. It sets the owner of the template to the creator of the proxy and sets the number of shares to the number of shares passed in.

    function initialize(address _safeAddress, uint256 _numShares, address _owner)
        external
    {
        require(_safeAddress != address(0x0), "Safe must already be initialized");
        safeAddress = _safeAddress;
        this.transferOwnership(_owner);
        _mint(safeAddress, _numShares);
        capTable.numShares = totalSupply();
        safeCapTable.valuation = 0;
        // The founders own 100% of the company at the start; percentages have 4 decimal precision; the below value is interpreted as 100.0%
        safeCapTable.shareholderPercentages[msg.sender] = 1000;
        // @audit Log statements
    }

    function triggerInvestment(
        address investor,
        uint256 amount,
        uint256 postMoneyValuation
    ) external {
        require(
            approvedInvestorInvestments[investor] >= amount,
            "Investor must be approved for this amount"
        );
        // Allow the SAFE investor to invest a certain amount with a specified postMoneyValuation
        // For example, if the company has $0, the SAFE investor will invest $x for y% at a $(100*x / y) valuation where y is in decimal form
        newSAFEMoney(investor, amount, postMoneyValuation);
        approvedInvestorInvestments[investor] -= amount;
    }

    /**
     * @dev Used to add a new investor to the cap table and calculate the percentage of the company they own & new valuation.
     * NOTE: this function should only be used in a SAFE investment, not an equity financing round where new shares are added to the total.
     */
    function newSAFEMoney(
        address investor,
        uint256 cash,
        uint256 postMoneyValuation
    ) internal {
        require(cash > 0, "Investment must be greater than 0");
        safeCapTable.investors.push(investor);
        uint256 percentage = percent(cash, postMoneyValuation);
        // rebalance cap table and set new valuation
        // safeCapTable.shareholderPercentages[owner] -= percentage;
        safeCapTable.shareholderPercentages[investor] = percentage;
        safeCapTable.totalInvested += cash;
        safeCapTable.valuation = postMoneyValuation;

        emit NewMoney(investor, cash, percentage, block.timestamp);
    }

    // This function is triggered when the company is dissolved before an equity financing round. This function should be called after the investors have cashed out their shares.
    function SAFEdissolution() external onlyOwner returns (bool) {
        require(safeCapTable.valuation != 0, "SAFE is not worth anything");
        for (uint256 i = 0; i < safeCapTable.investors.length; i++) {
            address investor = safeCapTable.investors[i];
            uint256 shares = balanceOf(investor);
            _burn(investor, shares);
        }
        require(
            totalSupply() == balanceOf(this.owner()),
            "All investor shares must be burned"
        );
        return true;
    }

    // This function is triggered when the company is dissolved after an equity financing round
    function dissolution() external onlyOwner returns (bool) {
        require(capTable.valuation != 0, "SAFE is not worth anything");
        for (uint256 i = 0; i < capTable.investors.length; i++) {
            address investor = capTable.investors[i];
            uint256 shares = balanceOf(investor);
            uint256 cash = (shares * capTable.valuation) / capTable.numShares;
            _burn(investor, shares);
            capTable.valuation -= cash;
        }
        require(
            totalSupply() == balanceOf(this.owner()),
            "All investor shares must be burned"
        );

        return true;
    }

    // This function is when the shares convert and a new round is initiated. Must be sure to increase options before calling this if necessary
    // TODO: fuzzing, formal verification
    function startPricedRound(
        address[] memory investors,
        uint256 postMoneyValuation
    ) external onlyOwner {
        //TODO: add checks to make sure logic is flowing smoothly
        // Convert SAFEs
        // get total dilution to founders and options
        uint256 totalDilution = uint256(
            safeCapTable.totalInvested / safeCapTable.valuation
        );
        // get the dilution percentage
        totalDilution = percent(totalDilution, 100);
        // dilute founders
        // TODO: if 4 digit precision is used, divide percentages by 100
        safeCapTable.shareholderPercentages[this.owner()] =
            (totalDilution * safeCapTable.shareholderPercentages[this.owner()]);
        // dilute options
        safeCapTable.shareholderPercentages[address(this)] =
            (totalDilution *
                safeCapTable.shareholderPercentages[address(this)]);
        // calculate new number of shares and mint ERC20 tokens for them
        uint256 newNumberShares = (capTable.numShares *
            postMoneyValuation) / safeCapTable.valuation;
        _mint(safeAddress, (newNumberShares - capTable.numShares));
        // convert SAFE shares: safePercentage * newShares
        for (uint256 i = 0; i < safeCapTable.investors.length; i++) {
            // add the SAFE investor to the cap table investor list
            capTable.investors.push(safeCapTable.investors[i]);
            // calculate the amount of shares the SAFE investor has
            uint256 shares = (newNumberShares *
                safeCapTable.shareholderPercentages[
                    safeCapTable.investors[i]
                ]);
            // update shareholder percentage in the cap table
            capTable.shareholderPercentages[
                safeCapTable.investors[i]
            ] = percent(shares, newNumberShares);
            // allocate token shares to the SAFE investor
            transferFrom(safeAddress, safeCapTable.investors[i], shares);
        }
        // convert option shares: optionPercentage * newShares
        uint256 optionShares = (newNumberShares *
            safeCapTable.shareholderPercentages[address(this)]);
        capTable.shareholderPercentages[address(this)] = percent(
            optionShares,
            newNumberShares
        );
        // recalculate owner shares
        uint256 ownerShares = (newNumberShares *
            safeCapTable.shareholderPercentages[this.owner()]);
        capTable.shareholderPercentages[this.owner()] = percent(
            ownerShares,
            newNumberShares
        );
        // calculate price per share
        capTable.pricePerShare = postMoneyValuation / newNumberShares;
        // find total raise
        uint256 totalRaise = postMoneyValuation - safeCapTable.valuation;
        // add series investors
        for (uint256 i = 0; i < investors.length; i++) {
            require(
                approvedInvestorInvestments[investors[i]] > 0,
                "Investor is not approved for this round"
            );
            capTable.investors.push(investors[i]);
            // find the percentage of the company the investor owns
            uint256 sharePercentage = percent(
                approvedInvestorInvestments[investors[i]],
                totalRaise
            );
            capTable.shareholderPercentages[investors[i]] = sharePercentage;
            // calculate the number of shares the investor owns
            uint256 shares = (newNumberShares *
                capTable.shareholderPercentages[investors[i]]);
            // allocate token shares to the SAFE investor
            transferFrom(safeAddress, safeCapTable.investors[i], shares);
        }
        capTable.totalInvested += totalRaise;
    }

    // Utility functions

    function percent(uint256 numerator, uint256 denominator) public pure returns (uint256) {
        require(denominator > 0, "Denominator cannot be zero");
        // TODO: consider multiplying by 10000 to achieve 4 digit precision
        return (numerator * 100) / denominator;
    }


    function cashOut(uint256 amount) external {
        require(
            capTable.shareholderPercentages[msg.sender] >= percent(amount, capTable.valuation),
            "You do not own enough shares"
        );
        // update user share balance
        capTable.shareholderPercentages[msg.sender] -= percent(amount, capTable.valuation);
        transferFrom(msg.sender, safeAddress, amount);
        emit CashOut(msg.sender, amount);
    }

    function addOptions(uint256 options) external onlyOwner {
        require(options < 1000, "cannot exceed 100%");
        safeCapTable.shareholderPercentages[this.owner()] -= options;
        safeCapTable.shareholderPercentages[address(this)] += options;
        require(options < 1000, "cannot exceed 100%");
    }

    function getValuation() external view returns (uint256) {
        return safeCapTable.valuation;
    }

    // All investors MUST be approved
    function approveInvestor(address investor, uint256 investment)
        public
        onlyOwner
    {
        require(investment > 0, "Investment must be more than 0");
        approvedInvestorInvestments[investor] = investment;
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        return super.transfer(recipient, amount);
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return super.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        return super.approve(spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    receive() external payable {
    // increase the valuation of the safe
    capTable.valuation += msg.value;
    }

    fallback() external payable {
        capTable.valuation += msg.value;
    }
}
