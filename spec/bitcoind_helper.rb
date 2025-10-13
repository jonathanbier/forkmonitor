# frozen_string_literal: true

# rubocop:disable Style/MixinUsage
# TODO: use a module
require 'pycall/import'
include PyCall::Import
pyimport :sys
sys.path.insert(0, '.')
pyimport :util

TestWrapper = util.TestWrapper
BUILD_TEST_WRAPPER = PyCall.getattr(util, :build_test_wrapper)

def new_test_wrapper(*args)
  BUILD_TEST_WRAPPER.call(*args)
end
# rubocop:enable Style/MixinUsage
