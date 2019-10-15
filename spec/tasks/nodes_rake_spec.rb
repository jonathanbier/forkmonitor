require 'spec_helper'

describe "nodes:poll" do
  include_context "rake"

  it "should call :poll! on Node" do
    expect(Node).to receive(:poll!)
    subject.invoke
  end
  
  it "should call :poll! on Node with a list of coins" do
    expect(Node).to receive(:poll!).with({:coins=>["BTC", "BCH"]})
    subject.invoke("BTC", "BCH")
  end
end

describe "nodes:poll_repeat" do
  include_context "rake"

  it "should call :pollrepeat! on Node" do
    expect(Node).to receive(:poll_repeat!)
    subject.invoke
  end
  
  it "should call :pollrepeat! on Node with a list of coins" do
    expect(Node).to receive(:poll_repeat!).with({:coins=>["BTC", "BCH"]})
    subject.invoke("BTC", "BCH")
  end
end

describe "nodes:heavy_checks_repeat" do
  include_context "rake"

  it "should call :heavy_checks_repeat! on Node" do
    expect(Node).to receive(:heavy_checks_repeat!)
    subject.invoke
  end
  
  it "should call :heavy_checks_repeat! on Node with a list of coins" do
    expect(Node).to receive(:heavy_checks_repeat!).with({:coins=>["BTC", "TBTC"]})
    subject.invoke("BTC", "TBTC")
  end
end
