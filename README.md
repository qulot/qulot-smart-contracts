# qulot-smart-contracts

## Description

A lottery smart contract used to store lotteries, tickets, rounds. Allow users to buy tickets and claim rewards. Uses a
special algorithm to get a random number instead of the traditional random and lottery functions

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

## Contracts

This project needs contract **QulotLottery** to operate. Other contracts you can customize or replace depending on the
purpose of use:

| Contract                                                              | Description                                                                                     |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [QulotLottery](#qulot-lottery)                                        | Contract used to store lotteries, tickets, rounds. Allow users to buy tickets and claim rewards |
| [ChainLinkRandomNumberGenerator](#chain-link-random-number-generator) | Contract used to get random numbers from ChainLink VRF                                          |
| [QulotAutomationTrigger](#qulot-automation-trigger)                   | Contract used to schedule call QulotLottery                                                     |

```sh
$ yarn deploy:goerli
```

### QulotLottery (required)

**QulotLottery** is a contract used to store lotteries, tickets, rounds. Allow users to buy tickets and claim rewards:

Deploy and verifying deployed contracts:

```sh
$ npx hardhat deploy:QulotLottery --network sepolia
```

First initialization for smart contract:

```bash
$ npx hardhat init:QulotLottery \
    --network sepolia \
    --address <deployed-address> \
    --random <deployed-random-generator-address> \
    --automation <deployed-automation-trigger-address>
```

### ChainLinkRandomNumberGenerator (optional)

**ChainLinkRandomNumberGenerator** is a contract used to get random numbers from
[ChainLink VRF](https://docs.chain.link/vrf/v2/introduction/):

Deploy and verifying deployed contracts:

```sh
$ npx hardhat deploy:ChainLinkRandomNumberGenerator --network sepolia
```

First initialization for smart contract:

```bash
$ npx hardhat init:ChainLinkRandomNumberGenerator \
    --network sepolia \
    --address <deployed-address> \
    --qulot <qulot-lottery-address>
```

### QulotAutomationTrigger (optional)

**QulotAutomationTrigger** is a duty contract to call the functions of **QulotLottery** like _Open_, _Close_, _Draw_,
_reward_ in a cron schedule setup:

This contract implemented the **AutomationCompatibleInterface** interface of
[ChainLink Automation](https://docs.chain.link/vrf/v2/introduction/).

Deploy and verifying deployed contracts:

```sh
$ npx hardhat deploy:QulotAutomationTrigger --network sepolia
```

First initialization for smart contract:

```bash
$ npx hardhat init:QulotAutomationTrigger \
    --network sepolia \
    --address <deployed-address> \
    --qulot <qulot-lottery-address>
```
