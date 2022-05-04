import argparse
import os
import sys
import importlib.util
from pathlib import Path

VENDOR_DIRECTORY = os.path.dirname(os.path.abspath(__file__)) + "/vendor"

sys.path.append(VENDOR_DIRECTORY + "/bitcoin/test/functional")
from test_framework.test_framework import BitcoinTestFramework
from test_framework.util import assert_equal
from test_framework.test_node import RPCOverloadWrapper
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
              configfile=os.path.abspath(VENDOR_DIRECTORY + "/bitcoin/test/config.ini"),
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

        self.options = argparse.Namespace
        self.options.nocleanup = nocleanup
        self.options.noshutdown = noshutdown
        self.options.cachedir = cachedir
        self.options.tmpdir = tmpdir
        self.options.loglevel = loglevel
        self.options.trace_rpc = trace_rpc
        self.options.port_seed = port_seed
        self.options.coveragedir = coveragedir
        self.options.configfile = configfile
        self.options.pdbonfailure = pdbonfailure
        self.options.usecli = usecli
        self.options.perf = perf
        self.options.randomseed = randomseed
        self.options.valgrind = False
        self.options.timeout_factor = 2
        self.options.descriptors = True

        self.options.bitcoind = None
        self.options.bitcoincli = None

        super().setup()

    def setup_nodes(self):
        # Bypass RPCOverloadWrapper's createwallet, because it adds an additional
        # argument "external_signer" which causes the command to fail when run
        # against v0.21
        if hasattr(RPCOverloadWrapper, 'createwallet'):
            delattr(RPCOverloadWrapper, "createwallet")

        self.add_nodes(self.num_nodes,
            versions=[230000] * self.num_nodes,
            binary=[os.path.abspath(VENDOR_DIRECTORY + "/v23.0/bin/bitcoind")] * self.num_nodes,
            binary_cli=[os.path.abspath(VENDOR_DIRECTORY + "/v23.0/bin/bitcoin-cli")] * self.num_nodes,
            # binary=[str(Path.home()) + "/bin/bitcoind"] * self.num_nodes,
            # binary_cli=[str(Path.home()) + "/bin/bitcoin-cli"] * self.num_nodes,
            extra_args=self.extra_args,
        )
        self.start_nodes()

    def connect_nodes(self, a, b):
        BitcoinTestFramework.connect_nodes(self, a, b)

    def disconnect_nodes(self, a, b):
        BitcoinTestFramework.disconnect_nodes(self, a, b)        

    def shutdown(self):
        super().shutdown()

    def createtaprootblock(self, txlist):
        # Code borrowed from feature_taproot.py
        block = create_block(tmpl=self.nodes[1].getblocktemplate(NORMAL_GBT_REQUEST_PARAMS), txlist=txlist)
        add_witness_commitment(block)
        block.rehash()
        block.solve()
        return block.serialize().hex()
