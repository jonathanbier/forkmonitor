require "rails_helper"

RSpec.describe Node, :type => :model do
  describe "version" do
    it "should be set" do
      node = create(:node)
      expect(node.version).not_to eq(0)
    end
  end
end
