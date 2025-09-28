require "test_helper"

class ActionSyncTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ActionSync::VERSION
  end

  test "it can create a client group" do
    user = User.create!(email: "zac@example.com")
    cg = ActionSync::ClientGroup.create!(id: ActionSync::Nanoid.generate, syncable: user, schema_version: "1")
    client = cg.clients.create!(id: ActionSync::Nanoid.generate)

    class TodoSchema < ActionSync::BaseSchema
      def model_class = Todo
      def scope = Todo.all.joins(:user)
      def attributes = %w[id title user_id created_at updated_at]
      def joined_attributes = [ [ "users.email", "email" ] ]
    end

    module Mutations
      class CreateTodo < ActionSync::BaseMutation
        attribute :id, :integer
        attribute :title, :string
        attribute :user_id, :integer
        attribute :now, :datetime

        def run
          Todo.create!(id:, title:, user_id:, updated_at: now, created_at: now)
        end
      end
    end

    pull = ActionSync::Pull.new(
      user,
      schema_version: "1",
      schema_classes: [ TodoSchema ],
      request_params: {
        clientGroupID: cg.id,
        schemaVersion: "1",
        cookie: nil
      }
    )
    pull_response = JSON.parse(pull.call)
    puts pull_response

    push = ActionSync::Push.new(
      user,
      mutation_registry: ActionSync::MutationRegistry.new(Mutations),
      request_params: {
        pushVersion: 1,
        clientGroupID: cg.id,
        profileID: ActionSync::Nanoid.generate,
        schemaVersion: "1",
        mutations: [
          clientID: client.id,
          id: 1,
          name: "createTodo",
          args: {
            id: 1,
            title: "test",
            user_id: user.id,
            now: Time.current.iso8601
          },
          timestamp: Time.current.to_i
        ]
      }
    )
    push.call

    pull = ActionSync::Pull.new(
      user,
      schema_version: "1",
      schema_classes: [ TodoSchema ],
      request_params: {
        clientGroupID: cg.id,
        schemaVersion: "1",
        cookie: pull_response["cookie"]
      }
    )
    pull_response = JSON.parse(pull.call)
    puts pull_response

    assert true
  end
end
