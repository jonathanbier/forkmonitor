## Test suite

When switching between a binary and custom Bitcoin Core branch, comment
the `binary` and `binary_cli` lines in `util.py`, update `travis.yml`
and update the commit hash in `bitcoind.sh`.

Currently the tests require a custom compiled version of Bitcoin Core.

### Custom Bitcoin Core branch


```sh
TRAVIS_BUILD_DIR=$PWD ./bitcoind.sh
```

Edit `bitcoin/test/config.ini` and replace `$TRAVIS_BUILD_DIR` with the root path
of this project.

To run Rails tests and monitor for changes:

```sh
guard
<hit enter>
```

### Bitcoin Core binary

Some of the tests require (a specific version of) Bitcoin Core. To install:

```
cd vendor/bitcoin
cp ../bitcoin-config.ini test/config.ini
test/get_previous_releases.py -b -t .. v0.21.0
```

## Javacsript tests

To run Rails tests in parallel (optionally set `PARALLEL_TEST_PROCESSORS`):

```sh
rake parallel:create
rake parallel:prepare
rake parallel:spec
```

To run Javascript tests and monitor for changes:

```sh
yarn test --watch
```
