require 'spec_helper'

describe "blocks:fetch_ancestors" do
  include_context "rake"

  it "should call :fetch_ancestors! on Node" do
    expect(Node).to receive(:fetch_ancestors!).with(1)
    subject.invoke("1")
  end
end
