# frozen_string_literal: true

module Api
  module V1
    class BlockTemplatesController < ApplicationController
      def index
        respond_to do |format|
          format.csv do
            @start = params[:start] || 0
            @templates = BlockTemplate.where('height >= ?', @start).order(id: :asc)
            send_data @templates.to_csv, filename: "#{controller_name}.csv"
          end
        end
      end
    end
  end
end
