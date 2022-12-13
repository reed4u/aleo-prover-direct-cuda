# Aleo Light Prover

# "Testnet 3 direct cuda"

The prover can directly connect to the beacon node and solve coinbase puzzles using the old thread pool config.

The document below is outdated and might not apply to this branch. Use `--help` to see how to run the prover.

## Introduction

A standalone Aleo prover build upon snarkOS and snarkVM, with multi-threading optimization.

It's called "light" because it won't spin up a full node, but instead will only run the prover part.

This prover only supports operators using [my modified code](https://github.com/reed4u/snarkOS) as it relies on the custom messaging protocol to work properly.

## Building

Install the dependencies:

```
git clone https://github.com/reed4u/snarkOS.git
git clone https://github.com/reed4u/snarkVM.git
git clone https://github.com/reed4u/aleo-prover-direct-cuda.git
cd aleo-prover-direct-cuda
cargo build --release --features cuda
cargo run --release --features cuda -- -g 0 -g1 -p APrivateKey1
```

## License

GPL-3.0-or-later
