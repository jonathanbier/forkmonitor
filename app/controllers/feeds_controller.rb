class FeedsController < ApplicationController

  def invalid_blocks
    respond_to do |format|
      format.rss do
        @invalid_blocks = InvalidBlock.all
      end
    end
  end

  def lagging_nodes
    respond_to do |format|
      format.rss do
        @lagging_nodes = Lag.all
      end
    end
  end

  def version_bits
    respond_to do |format|
      format.rss do
        @version_bits = VersionBit.all
      end
    end
  end

end
