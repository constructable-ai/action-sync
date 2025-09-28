module ActionSync
  class Push
    def initialize(syncable, mutation_registry:, request_params:)
      @syncable = syncable
      @mutation_registry = mutation_registry
      @request_params = ActiveSupport::HashWithIndifferentAccess.new(request_params)
      @client_group_id = @request_params[:clientGroupID]
      @mutations = @request_params[:mutations] || []
    end

    def call
      mutations.each do |mutation|
        process_mutation(
          client_id: mutation[:clientID],
          mutation_id: mutation[:id],
          name: mutation[:name],
          args: mutation[:args],
        )
      end
    end

    private
      attr_reader :syncable, :mutation_registry, :request_params, :client_group_id, :mutations

      # https://doc.replicache.dev/strategies/row-version#push
      def process_mutation(client_id:, mutation_id:, name:, args:)
        # 1. let errorMode = false
        error_mode = false
        begin
          # 2. Begin transaction
          ApplicationRecord.transaction(isolation:) do
            # 3. getClientGroup(body.clientGroupID), or default to:
            # {
            #   id: body.clientGroupID,
            #   userID
            #   cvrVersion: 0,
            # }
            client_group = ClientGroup.find_or_initialize_by(id: @client_group_id) do |cg|
              cg.syncable = syncable
              cg.schema_version = nil
              cg.cvr_version = 0
            end

            # 4. Verify requesting user owns specified client group.
            raise UnauthorizedPushError if syncable != client_group.syncable

            # 5. getClient(mutation.clientID) or default to:
            # {
            #   id: mutation.clientID,
            #   clientGroupID: body.clientGroupID,
            #   lastMutationID: 0,
            # }
            client = Client.find_or_initialize_by(id: client_id) do |c|
              c.client_group = client_group
              c.last_mutation_id = 0
            end

            # 6. Verify requesting client owns specified client.
            raise UnauthorizedPushError if client.client_group != client_group

            # 7. let nextMutationID = client.lastMutationID + 1
            next_mutation_id = client.last_mutation_id + 1

            # 8. Rollback transaction and skip mutation if already processed (mutation.id < nextMutationID)
            raise ActiveRecord::Rollback if mutation_id < next_mutation_id

            # 9. Rollback transaction and error if mutation from future (mutation.id > nextMutationID)
            raise FutureMutationError if mutation_id > next_mutation_id

            # 10. If errorMode != true then:
            if error_mode != true
              # i. Try business logic for mutation
              mutation_registry.lookup(name).new(client_group, args).call
              # ii. If error:
              # a. Log error
              # b. Abort transaction
              # c. Retry this transaction with errorMode = true
              # (this is done in the rescue block)
            end

            # 11. putClientGroup():
            # {
            #   id: body.clientGroupID,
            #   userID,
            #   cvrVersion: clientGroup.cvrVersion,
            # }
            client_group.save!

            # 12. putClient():
            # {
            #   id: mutation.clientID,
            #   clientGroupID: body.clientGroupID,
            #   lastMutationID: nextMutationID,
            # }
            client.last_mutation_id = next_mutation_id
            client.save!
          end
        rescue ActiveRecord::SerializationFailure
          sleep(rand(0.1..0.5))
          retry
        rescue ActionSync::Error
          raise
        # ii. If error:
        rescue StandardError => e
          # a. Log error
          ActionSync.logger.error(e)

          # b. Abort transaction
          # c. Retry this transaction with errorMode = true
          error_mode = true
          retry
        end
      end

      def isolation
        Rails.env.test? ? nil : :repeatable_read
      end
  end
end
