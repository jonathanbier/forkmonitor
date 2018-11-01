require "rails_helper"

RSpec.describe Block, :type => :model do
  describe "proof of work" do
    it "should be set" do
      block = create(:block)
      expect(block.work).not_to eq(nil)
    end
  end
end
