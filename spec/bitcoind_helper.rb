require 'pycall/import'
include PyCall::Import
pyimport :sys
sys.path.insert(0, ".")
pyfrom :util, import: :TestWrapper
