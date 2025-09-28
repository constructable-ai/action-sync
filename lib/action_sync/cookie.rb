module ActionSync
  class Cookie
    attr_reader :order, :cvr_id

    def initialize(params)
      @order = params[:order]&.then { it.to_i }
      @cvr_id = params[:cvr_id]
    end
  end
end
