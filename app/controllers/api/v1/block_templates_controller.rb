class Api::V1::BlockTemplatesController < ApplicationController
  def index
    respond_to do |format|
      format.csv {
        @start = params[:start] ? params[:start] : 0
        @templates = BlockTemplate.where("height >= ?", @start).order(id: :asc)
        send_data @templates.to_csv, filename: "#{self.controller_name}.csv"
      }
    end
  end

end
