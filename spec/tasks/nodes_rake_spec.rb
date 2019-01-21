require 'spec_helper'

describe "nodes:poll" do
  include_context "rake"

  it "should call :poll! on Node" do
    expect(Node).to receive(:poll!)
    subject.invoke
  end
end

describe "nodes:poll_repeat" do
  include_context "rake"

  it "should call :pollrepeat! on Node" do
    expect(Node).to receive(:poll_repeat!)
    subject.invoke
  end
end
