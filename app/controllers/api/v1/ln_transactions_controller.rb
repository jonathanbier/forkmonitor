class Api::V1::LnTransactionsController < ApplicationController

  def index
    latest = @resource_class.last_updated_cached
    if stale?(etag: latest.try(:updated_at), last_modified: latest.try(:updated_at))
      respond_to do |format|
        format.json {
          render json: Rails.cache.fetch("api/v1/#{self.controller_name}.json") {
            resource_class.all_with_block_cached.to_json
          }
        }
        format.csv {
          send_data resource_class.to_csv, filename: "#{self.controller_name}.csv"
        }
      end
    end
  end

  private

  def resource_class
    @resource_class ||= case self.controller_name
    when "ln_penalties"
      PenaltyTransaction
    when "ln_sweeps"
      SweepTransaction
    when "ln_uncoops"
      MaybeUncoopTransaction
    end
  end

end
