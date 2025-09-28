module ActionSync
  class Engine < ::Rails::Engine
    isolate_namespace ActionSync
    config.generators.api_only = true

    initializer "action_sync.set_defaults" do
      ActionSync.logger ||= ActiveSupport::TaggedLogging.new(
        Rails.logger
      )
    end
  end
end
