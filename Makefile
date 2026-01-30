-include .env

.PHONY: all test clean deploy deployDSC help install snapshot format anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]     Deploy contracts"
	@echo "  make deployDSC [ARGS=...]  Deploy DSC system"
	@echo "  make test                  Run tests"
	@echo "  make snapshot              Create gas snapshot"
	@echo "  make format                Format code"
	@echo ""
	@echo "Examples:"
	@echo "  make deployDSC ARGS=\"--network sepolia\""
	@echo "  make deployDSC ARGS=\"--network mainnet\""

all: clean remove install update build

clean:
	forge clean

remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules

install:
	forge install cyfrin/foundry-devops@0.2.2 --no-commit && \
	forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && \
	forge install foundry-rs/forge-std@v1.8.2 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.0.2 --no-commit

update:
	forge update

build:
	forge build

test:
	forge test

test-v:
	forge test -vvv

test-fork-sepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)

test-fork-mainnet:
	@forge test --fork-url $(MAINNET_RPC_URL)

snapshot:
	forge snapshot

format:
	forge fmt

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Network args
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network mainnet,$(ARGS)),--network mainnet)
NETWORK_ARGS := --rpc-url $(MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# Deploy DSC system
deployDSC:
	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS)

# Alias for deployDSC
deploy: deployDSC
