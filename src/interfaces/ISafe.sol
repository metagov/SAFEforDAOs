// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title ISAFE
 * @dev Interface for the SAFE contract as defined in the legal contract (https://www.ycombinator.com/documents)
 */

interface ISAFE {
    /**
     * @dev Emitted when an equity financing round has closed.
     */
    event EquityFinancing(
        address[] indexed investors,
        uint256 preMoneyValuation,
        uint256 postMoneyValuation,
        uint256 amountRaised,
        uint256 timestamp
    );

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

    event Termination(
        address indexed investor,
        uint256 timestamp,
        uint256 newValuation
    );

    /**
     * @dev Returns the valuation of the company in USD
     */
    function getValuation() external view returns (uint256);

    /**
     * @dev Called by the Investor to initiate a SAFE Investment. This function is typically called after the legal contract is signed
     *
     * Note: This function can be called by anyone, but the company must approve the transaction to avoid unwarranted investments.
     */
    function triggerInvestment(address investor, uint256 amount) external;

    /**
     * @dev Called by the Investor to terminate the SAFE. This function is typically called after formal agreement. This function
     * returns a bool indicating whether the agreement was successfully terminated.
     */
    function terminate(address investor) external returns (bool);

    /**
     * @dev Marks the end of a company; returns funds to investors based on priority.
     *
     * Note: This function can only be called by the Company (onlyOwner modifier should be added). This function returns a bool
     * indicating whether the company was successfully dissolved.
     */
    function dissolution() external returns (bool);

    /**
     * @dev Sets the discount rate for an investor.
     *
     * Note: Investor should be defined as a struct with a discount rate, a timestamp, and a number representing how much they invested
     */
    function setDiscount(address investor) external;

    /**
     * @dev Initiates a Priced Round where the SAFE investments convert to shares in the company.
     */
    function startPricedRound() external;

    /**
     * @dev Adds options to the cap table.
     */
    function addOptions(uint256 ops) external;
}
