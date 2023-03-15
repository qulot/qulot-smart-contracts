# qulot-smart-contracts

## Description

A lottery for ERC20 tokens built with Chainlink's VRF.

## Usage

### Pre Requisites

Before being able to run any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as an
environment variable. You can follow the example in `.env.example`. If you don't already have a mnemonic, you can use
this [website](https://iancoleman.io/bip39/) to generate one.

Then, proceed with installing dependencies:

```sh
$ yarn install
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ yarn compile
```

### TypeChain

Compile the smart contracts and generate TypeChain bindings:

```sh
$ yarn typechain
```

### Test

Run the tests with Hardhat:

```sh
$ yarn test
```

### Lint Solidity

Lint the Solidity code:

```sh
$ yarn lint:sol
```

### Lint TypeScript

Lint the TypeScript code:

```sh
$ yarn lint:ts
```

### Coverage

Generate the code coverage report:

```sh
$ yarn coverage
```

### Deploy And Initialize Contracts

Deploy the contracts to network:

```sh
$ yarn deploy:goerli
```

Data initialization for smart contract:

```sh
$ npx hardhat init:QulotLottery --network goerli --address <qulot-lottery-address>
$ npx hardhat init:QulotAutomationTrigger --network goerli --address <qulot-automation-trigger-address> --qulot-address <qulot-lottery-address>
```

Verifying deployed contracts:

```sh
$ npx hardhat verify --network goerli <address> <argument 1> <argument 2>
```
