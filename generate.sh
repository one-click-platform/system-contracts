#!/bin/bash

docker run -v $PWD:$PWD -w $PWD ethereum/solc:0.8.3 @openzeppelin/=$(pwd)/node_modules/@openzeppelin/ --overwrite --abi --bin -o ./build \
contracts/Auction.sol \
contracts/WETH.sol \
contracts/WERC721.sol

./bin/abigen  --abi ./build/Auction.abi --bin ./build/Auction.bin --type Auction --pkg generated --out ./generated/auction.go
./bin/abigen  --abi ./build/WETH.abi --bin ./build/WETH.bin --type WETH --pkg generated --out ./generated/weth.go
./bin/abigen  --abi ./build/WERC721.abi --bin ./build/WERC721.bin --type WERC721 --pkg generated --out ./generated/werc721.go
