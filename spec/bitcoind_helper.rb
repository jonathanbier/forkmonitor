# frozen_string_literal: true

# rubocop:disable Style/MixinUsage
# TODO: use a module
require 'pycall/import'
include PyCall::Import
pyimport :sys
sys.path.insert(0, '.')
pyfrom :util, import: :TestWrapper
# rubocop:enable Style/MixinUsage
