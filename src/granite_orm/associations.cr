module Granite::ORM::Associations
  # define getter and setter for parent relationship
  macro belongs_to(model_name)
    field {{model_name.id}}_id : Int64

    # retrieve the parent relationship
    def {{model_name.id}}
      if parent = {{model_name.id.camelcase}}.find {{model_name.id}}_id
        parent
      else
        {{model_name.id.camelcase}}.new
      end
    end

    # set the parent relationship
    def {{model_name.id}}=(parent)
      @{{model_name.id}}_id = parent.id
    end
  end

  macro owned_by(parent_class_name, column = nil)
    {% underscored_class_name = parent_class_name.id.underscore %}
    {% if !column %}
      {% column = underscored_class_name + "_id" %}
    {% end %}
    # retrieve the parent relationship
    def {{underscored_class_name}}() : {{parent_class_name}}?
      if ! {{column}}.nil?
        {{parent_class_name}}.find {{column}}
      else
        nil
      end
    end

    # set the parent relationship
    def {{parent_class_name.id.underscore}}=(a_person : Person)
      self.{{column}} = a_person.id
    end
  end

  macro has_many(children_table)
    def {{children_table.id}}
      {% children_class = children_table.id[0...-1].camelcase %}
      {% name_space = @type.name.gsub(/::/, "_").downcase.id %}
      {% table_name = SETTINGS[:table_name] || name_space + "s" %}
      return [] of {{children_class}} unless id
      foreign_key = "{{children_table.id}}.{{table_name[0...-1]}}_id"
      query = "WHERE #{foreign_key} = ?"
      {{children_class}}.all(query, id)
    end
  end

  macro has_some(children_class_name)
    def {{children_class_name.id.underscore}}s
      childrens_table = {{children_class_name}}.table_name
      return [] of {{children_class_name}} unless id
      table_fk_string = "#{childrens_table}.#{@@foreign_key}"
      query = "WHERE #{table_fk_string} = ?"
      {{children_class_name}}.all(query, id)
    end
    # from has_some({{children_class_name.id}})
    def {{children_class_name.id.underscore}}s=(new_children :
                                                Array({{children_class_name}}))
      self.save unless self.id
      # TODO: figure out how to wrap this in a transaction
      # find existing relations
      current_kids = {{children_class_name.id.underscore}}s
      impending_orphans =  current_kids - new_children
      new_kids = new_children - current_kids
      # orphan ones who aren't in new list
      impending_orphans.each do | kid |
        kid.{{ SETTINGS[:foreign_key] }} = nil
        kid.save
      end

      # add ones who are in new list
      new_kids.each do | kid |
        kid.{{ SETTINGS[:foreign_key] }} = self.id
        kid.save
      end
      #END bit that should be in a transaction
    end
  end

  macro has_some(children_class_name, through)
    def {{children_class_name.id.underscore}}s
      childrens_table = {{children_class_name.id}}.table_name
      through_table = {{through}}.table_name
      return Array({{children_class_name}}).new() unless id
      childrens_fk = {{children_class_name.id}}.foreign_key
      table_fk_string = "#{childrens_table}.#{@@foreign_key}"
      query = "JOIN #{through_table} ON " \
              "#{through_table}.#{childrens_fk} = #{childrens_table}.id " \
              "WHERE #{through_table}.#{@@foreign_key}= ?"
      {{children_class_name}}.all(query, self.id)
    end
    #new hotnessvvv
    def {{children_class_name.id.underscore}}s=(new_children : Array({{children_class_name}}))
      self.save unless self.id
      # OK so, the trick with this method is that without reflection
      # we can never access what the foreign key of the child class is
      # IN the macro. We can only make code that acceses it at runtime
      # which results in more code and extra queries. :/

      through_table = {{through}}.table_name
      # find existing relations
      query = "WHERE #{@@foreign_key} = ?"
      current_joins = {{through}}.all(query, self.id)

      kids_foreign_key = {{children_class_name}}.foreign_key
      # TODO: figure out how to wrap this in a transaction
      #save the new kids so that any newly created ones will have ids

      new_children.each{|kid|kid.save}

      # sadly, without .send i have to do this via another db query
      query = "WHERE #{kids_foreign_key} in " \
        "(#{new_children.map{|c|c.id}.compact.join(", ")}) "\
        "and #{@@foreign_key} = ?"

      saveable_joins = new_children.size > 0 ? {{through}}.all(query, [self.id]) : Array({{through}}).new

      the_doomed_joins = current_joins - saveable_joins
      the_doomed_joins.each do |walking_dead|
        walking_dead.destroy
      end

      kids_after_aforementioned_massacre = {{children_class_name.id.underscore}}s
      kids_needing_a_join = new_children - kids_after_aforementioned_massacre
      if kids_needing_a_join.size > 0
        # have to do this in SQL not methods, because again,
        # we still don't know the foreign key of the kid until runtime
        # but this'll be more efficient anyway
        insert_statement = String.build do |str|
          str << "insert into #{through_table} (#{@@foreign_key}, #{kids_foreign_key}) VALUES "
          kids_needing_a_join.each_index do | idx |
            kid = kids_needing_a_join[idx]
            if idx > 0
              str << ", "
            end
            str << "(#{self.id}, #{kid.id})"
          end
        end
        {{through}}.exec(insert_statement)
      end
      #END bit that should be in a transaction

    end
  end

  # define getter for related children
  macro has_many(children_table, through)
    def {{children_table.id}}
      {% children_class = children_table.id[0...-1].camelcase %}
      {% name_space = @type.name.gsub(/::/, "_").downcase.id %}
      {% table_name = SETTINGS[:table_name] || name_space + "s" %}
      return [] of {{children_class}} unless id
      query = "JOIN {{through.id}} ON {{through.id}}.{{children_table.id[0...-1]}}_id = {{children_table.id}}.id "
      query = query + "WHERE {{through.id}}.{{table_name[0...-1]}}_id = ?"
      {{children_class}}.all(query, id)
    end
  end
end
