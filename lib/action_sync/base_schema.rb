module ActionSync
  class BaseSchema
    def initialize(client_group)
      @client_group = client_group
    end

    def model_class
      raise NotImplementedError, "Subclasses must implement #model_class"
    end

    def scope
      raise NotImplementedError, "Subclasses must implement #scope"
    end

    def filter_scope
      scope
    end

    def attributes
      raise NotImplementedError, "Subclasses must implement #attributes"
    end

    def key
      model_class.name.underscore.pluralize
    end

    def camel_key
      key.camelize(:lower)
    end

    def joined_attributes
      []
    end

    def select_sql
      attribute_selectors = attributes.map do |attribute|
        "#{model_class.table_name}.#{attribute} AS #{attribute}"
      end
      joined_attributes.each do |attribute|
        attribute_selectors << "#{attribute[0]} AS #{attribute[1]}"
      end
      attribute_selectors.join(", ")
    end

    def current_versions
      current_table = model_class.table_name
      entity_id_cast = model_class.columns_hash["id"].type == :uuid ? "#{current_table}.id::text" : "#{current_table}.id"
      sql = filter_scope.select(<<~SELECT).to_sql
        '#{model_class.name}' AS entity_type,
        #{entity_id_cast} as entity_id,
        #{version_select_sql} AS version
      SELECT
      ApplicationRecord.with_connection { it.select_rows(sql) }
    end

    def current_rows(ids)
      id_type = model_class.columns_hash["id"].type
      array_type = "#{id_type}[]"

      query = filter_scope
        .where("#{model_class.table_name}.id = ANY(ARRAY[?]::#{array_type})", ids)
        .select(select_sql)

      ApplicationRecord.with_connection { it.select_all(query).to_a }
    end

    def process_row(row)
      row
    end

    def version_select_sql
      "#{model_class.table_name}.xmin::text::bigint"
    end
  end
end
