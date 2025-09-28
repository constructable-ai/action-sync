module ActionSync
  class MutationRegistry
    def initialize(mutations_module)
      @mutations_module = mutations_module
    end

    def lookup(name)
      class_name = name.camelize
      klass = if @mutations_module.present?
        "#{@mutations_module.name}::#{class_name}".constantize
      else
        class_name.constantize
      end
      raise "Found mutation that does not inherit from ActionSync::BaseMutation" unless klass < ActionSync::BaseMutation
      klass
    end

    private
  end
end
