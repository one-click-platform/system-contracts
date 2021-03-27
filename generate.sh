#!/bin/bash

docker run -v $PWD:$PWD -w $PWD ethereum/solc:0.7.2 --overwrite --abi --bin -o ./build contracts/*.sol

./bin/abigen  --abi ./build/Auction.abi --bin ./build/Auction.bin --type Auction --pkg generated --out ./generated/auction.go
./bin/abigen  --abi ./build/WETH.abi --bin ./build/WETH.bin --type WETH --pkg generated --out ./generated/weth.go
