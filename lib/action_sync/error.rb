module ActionSync
  class Error < StandardError; end
  class UnauthorizedPullError < Error; end
  class UnauthorizedPushError < Error; end
  class FutureMutationError < Error; end
end
