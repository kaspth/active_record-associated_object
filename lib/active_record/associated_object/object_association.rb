module ActiveRecord::AssociatedObject::ObjectAssociation
  extend ActiveSupport::Concern

  using Module.new {
    refine Module do
      def extend_source_from(chunks, &block)
        location = caller_locations(1, 1).first
        source_chunks = Array(chunks).flat_map(&block)
        class_eval source_chunks.join("\n\n"), location.path, location.lineno
      end
    end
  }

  included do
    class_attribute :associated_object_ivar_names,
      default: [],
      instance_accessor: false,
      instance_predicate: false
  end

  class_methods do
    def has_object(*names, **callbacks)
      self.associated_object_ivar_names += names.map { |n| :"@#{n}" }

      extend_source_from(names) do |name|
        "def #{name}; @#{name} ||= #{self.name}::#{name.to_s.classify}.new(self); end"
      end

      extend_source_from(names) do |name|
        callbacks.map do |callback, method|
          "#{callback} { #{name}.#{method == true ? callback : method} }"
        end
      end
    end
  end

  def init_internals
    self.class.associated_object_ivar_names.each do |name|
      instance_variable_set(name, nil)
    end

    super
  end
end
