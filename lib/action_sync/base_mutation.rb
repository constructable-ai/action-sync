module ActionSync
  class BaseMutation
    include ActiveModel::Model
    include ActiveModel::Attributes

    def initialize(client_group, params)
      @client_group = client_group
      params.permit! if params.is_a?(ActionController::Parameters)
      attributes = ActiveSupport::HashWithIndifferentAccess.new(params.to_h)
      transformed = attributes.deep_transform_keys { |key| key.to_s.underscore }
      sliced = transformed.slice(*self.class.attribute_names)
      super(sliced)
    end

    def run
      raise NotImplementedError, "Mutation must implement #run"
    end

    def call
      run
    end
  end
end
