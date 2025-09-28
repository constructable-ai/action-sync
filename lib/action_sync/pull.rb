module ActionSync
  class Pull
    def initialize(syncable, schema_version:, schema_classes:, request_params:)
      @syncable = syncable
      @schema_version = schema_version.to_s
      @schema_classes = schema_classes
      @client_group_id = request_params[:clientGroupID]
      @request_schema_version = request_params[:schemaVersion]&.to_s
      @cookie = Cookie.new(request_params[:cookie] || {})
    end

    def call
      return version_not_supported_response if @schema_version != @request_schema_version

      # 1. let prevCVR = getCVR(body.cookie.cvrID)
      prev_cvr = ClientViewRecord.find_by(id: cookie.cvr_id)

      # 2. let baseCVR = prevCVR or default to:
      # {
      #   "id": "",
      #   "entries": {}
      # }
      base_cvr = prev_cvr || ClientViewRecord.new(id: "")
      cached_versions = base_cvr.version_map

      # 3. Begin transaction
      result = ApplicationRecord.transaction(isolation:) do
        # 4. getClientGroup(body.clientGroupID), or default to:
        # {
        #   id: body.clientGroupID,
        #   userID,
        #   cvrVersion: 0,
        # }
        client_group = ClientGroup.find_or_initialize_by(id: client_group_id) do |cg|
          cg.syncable = syncable
          cg.schema_version = schema_version
          cg.cvr_version = 0
        end

        # 5. Verify requesting client group owns requested client.
        raise UnauthorizedPullError if syncable != client_group.syncable

        schemas = schema_classes.map { it.new(client_group) }

        current_versions = VersionMap.new.tap do |current_versions|
          schemas.each do |schema|
            schema.current_versions.each do |row|
              current_versions.insert_version(row[0], row[1], row[2])
            end
          end

          # 7. Read all clients in the client group.
          current_client_versions.each do |row|
            current_versions.insert_version(row[0], row[1], row[2])
          end
        end

        # 8. Build nextCVR from entities and clients.
        # (this is current_versions)

        # 9. Calculate the difference between baseCVR and nextCVR
        diff = VersionsDiff.new(cached_versions: cached_versions, current_versions: current_versions)

        # 10. If prevCVR was found and two CVRs are identical then exit this transaction and return a no-op PullResopnse to client:
        # {
        #   cookie: prevCookie,
        #   lastMutationIDChanges: {},
        #   patch: [],
        # }
        noop = prev_cvr.present? && diff.puts("ActionSync::Client").empty? && diff.dels("ActionSync::Client").empty? && schemas.all? do |schema|
          name = schema.model_class.name
          diff.puts(name).empty? && diff.dels(name).empty?
        end

        return noop_response if noop

        # 11. Fetch all entities from database that are new or changed between baseCVR and nextCVR
        patch_json = String.new("[").tap do |patch_json|
          patch_json << %({"op":"clear"},) if prev_cvr.nil?
          patch_json << %({"op":"put","key":"init","value":{}})

          schemas.each do |schema|
            diff.dels(schema.model_class.name).each do |id|
              patch_json << %(,{"op":"del","key":"#{schema.camel_key}/#{id}"})
            end
            schema.current_rows(diff.puts(schema.model_class.name)).each do |raw_row|
              row = schema.process_row(raw_row)
              row.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
              patch_json << %(,{"op":"put","key":"#{schema.camel_key}/#{row["id"]}","value":#{row.to_json}})
            end
          end
          patch_json << "]"
        end

        # 12. let clientChanges = clients that are new or changed since baseCVR
        last_mutation_id_changes = current_versions.versions("ActionSync::Client")

        # 13. let nextCVRVersion = Math.max(pull.cookie?.order ?? 0, clientGroup.cvrVersion) + 1
        next_cvr_version = [ cookie&.order || 0, client_group.cvr_version ].max + 1

        # 14. putClientGroup()
        # {
        #   id: clientGroup.id,
        #   userID: clientGroup.userID,
        #   cvrVersion: nextCVRVersion,
        # }
        client_group.cvr_version = next_cvr_version
        client_group.save!

        # 15. Commit
        { patch_json:, current_versions:, last_mutation_id_changes:, client_group: }
      end

      patch_json = result[:patch_json]
      current_versions = result[:current_versions]
      last_mutation_id_changes = result[:last_mutation_id_changes]
      client_group = result[:client_group]

      # 16. let nextCVRID = randomID()
      next_cvr_id = ActionSync.id_generator.call

      # 17. putCVR(nextCVR)
      next_cvr = client_group.client_view_records.create!(id: next_cvr_id)
      next_cvr.upload_cached_versions(current_versions)

      # 18. Create a PullResponse with:
      #   i. A patch with:
      #     a. op:clear if prevCVR === undefined
      #     b. op:put for every created or changed entity
      #     c. op:del for every deleted entity
      #   ii. {order: nextCVRVersion, cvrID} as the cookie.
      #   iii. lastMutationIDChanges with entries for every client that has changed.
      <<~JSON
        {
          "cookie": { "order": #{client_group.cvr_version}, "cvr_id": "#{next_cvr_id}" },
          "lastMutationIDChanges": #{last_mutation_id_changes.to_json},
          "patch": #{patch_json}
        }
      JSON
    rescue ActiveRecord::SerializationFailure
      sleep(rand(0.1..0.5))
      retry
    end

    private
      attr_reader :syncable, :client_group_id, :schema_version, :schema_classes, :cookie

      def current_client_versions
        ApplicationRecord.with_connection { it.select_rows(<<~SQL) }
          SELECT
            '#{ActionSync::Client.name}' as entity_type,
            #{ActionSync::Client.table_name}.id as entity_id,
            #{ActionSync::Client.table_name}.last_mutation_id as version
          FROM #{ActionSync::Client.table_name}
          WHERE #{ActionSync::Client.table_name}.client_group_id = '#{client_group_id}'
        SQL
      end

      def version_not_supported_response
        { error: "VersionNotSupported", versionType: "schema" }.to_json
      end

      def noop_response
        <<~JSON
          {
            "cookie": { "order": #{cookie&.order}, "cvr_id": "#{cookie&.cvr_id}" },
            "lastMutationIDChanges": {},
            "patch": []
          }
        JSON
      end

      def isolation
        Rails.env.test? ? nil : :repeatable_read
      end
  end
end
