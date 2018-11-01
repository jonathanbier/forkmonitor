require 'spec_helper'

describe "nodes:poll" do
  include_context "rake"

  it "should call :poll! on each node" do
    expect(BitcoinClient).to receive(:poll!)
    subject.invoke
  end
end
