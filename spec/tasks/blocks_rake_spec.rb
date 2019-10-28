require 'spec_helper'

describe "blocks:fetch_ancestors" do
  include_context "rake"

  it "should call :fetch_ancestors! on Node" do
    expect(Node).to receive(:fetch_ancestors!).with(1)
    subject.invoke("1")
  end
end

describe "blocks:check_inflation" do
  include_context "rake"

  it "should call check_inflation! on Block for coin" do
    expect(InflatedBlock).to receive(:check_inflation!).with({coin: :btc, :max=>nil})
    subject.invoke("BTC")
  end
end
