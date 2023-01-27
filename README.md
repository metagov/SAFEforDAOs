# SAFEforDAOs
A computational Simple Agreement for Future Equity (SAFE) for DAOs and other digitally-constituted organizations, plus a clause-to-code mapping between legal SAFEs and computational SAFEs to verify their strategic equivalence. Below is a diagram of the compositional game used to model the SAFE.

<img width="2061" alt="Screen Shot 2023-01-27 at 1 47 53 PM" src="https://user-images.githubusercontent.com/40670744/215169706-41ea459c-7fd0-47e1-be07-11a1b9b2a703.png">

Simple Agreements for Future Equity (SAFEs) are a popular class of legal contracts that investors and companies use to fund early-stage startups. They have been used across several industries to help investors join early funding rounds without dilution and to help companies receive funding without the hassle of organizing a formal round. Startup DAOs have similar problems as these traditional startups—they want to raise funding quickly while promising investors tokens from a token sale, but many of these projects do not want to and should not create a token too early. If DAOs could raise funding without direct token sales, many more projects could get off the ground.

We believe that DAOs, irrespective of their legal status, should have access to well-defined SAFEs for better and faster scalability. And we believe that companies, even those that are not DAOs, may benefit from implementing certain parts of their SAFEs within a smart contract. 

In this standard, we specify a computational template of a SAFE. Using game-theoretic tools, we further show that (1) this computational SAFE is strategically equivalent to a standard legal SAFE and (2) elements of both can be traded off while preserving strategic equivalence.

### Smart Contracts
The smart contract specification in this project allows DAOs to create a proxy contract that represents a SAFE. Shares are represented as ERC20 tokens. Deposits are denoted in 256 bit unsigned integers of ether. We implement EIP1167[https://eips.ethereum.org/EIPS/eip-1167] to help DAOs create their own instance of a SAFE that is game theoretically similar to the legal contract and lasts until an exit. 
