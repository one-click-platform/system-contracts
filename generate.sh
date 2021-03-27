#!/bin/bash

docker run -v $PWD:$PWD -w $PWD ethereum/solc:0.7.2 @openzeppelin/=$(pwd)/node_modules/@openzeppelin/ --overwrite --abi --bin -o ./build contracts/*.sol

./bin/abigen  --abi ./build/Auction.abi --bin ./build/Auction.bin --type Auction --pkg generated --out ./generated/auction.go
