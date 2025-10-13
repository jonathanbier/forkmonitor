import argparse
import os
import sys
import importlib.util
import tempfile
import textwrap
from pathlib import Path

VENDOR_DIRECTORY = os.path.dirname(os.path.abspath(__file__)) + "/vendor"


def _resolve_version_dir():
    """Return the expected packaged bitcoind version directory."""
    override = os.environ.get("BITCOIN_VERSION_DIR")
    if override:
        path = Path(override).expanduser()
        if path.exists():
            return path
        raise FileNotFoundError(f"Required bitcoind version v28.2 not found at {path}")

    path = Path(VENDOR_DIRECTORY) / "v28.2"
    if path.exists():
        return path
    raise FileNotFoundError("Required bitcoind version v28.2 not found under vendor/")


def _version_code(version_dir: Path) -> int:
    """Translate a directory name like v28.2 into the numeric version code expected by BitcoinTestFramework."""
    name = version_dir.name.lstrip('v')
    parts = name.split('.')
    while len(parts) < 3:
        parts.append('0')
    major, minor, patch = (int(part) for part in parts[:3])
    return major * 10000 + minor * 100 + patch

sys.path.append(VENDOR_DIRECTORY + "/bitcoin/test/functional")
from test_framework.test_framework import BitcoinTestFramework, TestStatus
from test_framework.util import assert_equal
from feature_taproot import create_block
from test_framework.blocktools import NORMAL_GBT_REQUEST_PARAMS, add_witness_commitment

class TestWrapper(BitcoinTestFramework):
    """Wrapper Class for BitcoinTestFramework.
    Provides the BitcoinTestFramework rpc & daemon process management
    functionality to external python projects."""

    def set_test_params(self):
        # This can be overriden in setup() parameter.
        self.num_nodes = 1

    def run_test(self):
        pass

    def setup(self,
              setup_clean_chain=True,
              num_nodes=1,
              network_thread=None,
              rpc_timeout=60,
              supports_cli=False,
              bind_to_localhost_only=True,
              nocleanup=False,
              noshutdown=False,
              cachedir=os.path.abspath(VENDOR_DIRECTORY + "/bitcoin/test/cache"),
              tmpdir=None,
              loglevel='ERROR',
              trace_rpc=False,
              port_seed=os.getpid(),
              coveragedir=None,
              pdbonfailure=False,
              usecli=False,
              perf=False,
              randomseed=None,
              extra_args=None):

        self.setup_clean_chain = setup_clean_chain
        self.num_nodes = num_nodes
        self.network_thread = network_thread
        self.rpc_timeout = rpc_timeout
        self.supports_cli = supports_cli
        self.bind_to_localhost_only = bind_to_localhost_only
        self.extra_args = extra_args
        self.uses_wallet = True

        version_dir = _resolve_version_dir()

        options = self.options
        options.nocleanup = nocleanup
        options.noshutdown = noshutdown
        options.cachedir = cachedir
        options.tmpdir = tmpdir
        options.loglevel = loglevel
        options.trace_rpc = trace_rpc
        options.port_seed = port_seed
        options.coveragedir = coveragedir
        options.pdbonfailure = pdbonfailure
        options.usecli = usecli
        options.perf = perf
        options.randomseed = randomseed
        options.valgrind = False
        options.timeout_factor = 2
        options.descriptors = True
        options.v2transport = getattr(options, 'v2transport', False)
        options.previous_releases_path = str(version_dir.parent)

        options.bitcoind = None
        options.bitcoincli = None

        super().setup()

    def setup_nodes(self):
        self.add_nodes(
            self.num_nodes,
            extra_args=self.extra_args,
            versions=[_version_code(_resolve_version_dir())] * self.num_nodes,
        )
        self.start_nodes()

    def connect_nodes(self, a, b):
        BitcoinTestFramework.connect_nodes(self, a, b)

    def disconnect_nodes(self, a, b):
        BitcoinTestFramework.disconnect_nodes(self, a, b)

    def shutdown(self):
        if not hasattr(self, "success"):
            self.success = TestStatus.FAILED
        super().shutdown()

    def createtaprootblock(self, txlist):
        # Code borrowed from feature_taproot.py
        block = create_block(tmpl=self.nodes[1].getblocktemplate(NORMAL_GBT_REQUEST_PARAMS), txlist=txlist)
        add_witness_commitment(block)
        block.solve()
        return block.serialize().hex()

if __name__ == '__main__':
    TestWrapper(__file__).main()


def build_test_wrapper(test_file=None):
    """Instantiate TestWrapper with a temporary config file pointing at vendor binaries."""

    version_dir = _resolve_version_dir()
    bitcoin_src_dir = Path(VENDOR_DIRECTORY) / "bitcoin"

    config_content = textwrap.dedent(
        f"""
        [environment]
        CLIENT_NAME=forkmonitor
        CLIENT_BUGREPORT=https://forkmonitor.info
        SRCDIR={bitcoin_src_dir}
        BUILDDIR={version_dir}
        EXEEXT=
        RPCAUTH={bitcoin_src_dir / 'share' / 'rpcauth' / 'rpcauth.py'}

        [components]
        ENABLE_WALLET=true
        ENABLE_CLI=true
        BUILD_BITCOIN_TX=true
        ENABLE_BITCOIN_UTIL=true
        ENABLE_BITCOIN_CHAINSTATE=true
        ENABLE_WALLET_TOOL=true
        ENABLE_BITCOIND=true
        ENABLE_FUZZ_BINARY=true
        ENABLE_EXTERNAL_SIGNER=true
        ENABLE_IPC=true
        """
    ).strip()

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".ini") as config_file:
        config_file.write(config_content)
        config_path = Path(config_file.name)

    argv_snapshot = sys.argv[:]
    argv0 = argv_snapshot[0] if argv_snapshot else ""

    try:
        sys.argv = [argv0, f"--configfile={config_path}"]
        return TestWrapper(str(test_file or Path(__file__)))
    finally:
        sys.argv = argv_snapshot
        try:
            config_path.unlink()
        except FileNotFoundError:
            pass
