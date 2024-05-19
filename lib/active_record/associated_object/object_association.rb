module ActiveRecord::AssociatedObject::ObjectAssociation
  def self.included(klass) = klass.extend(ClassMethods)

  using Module.new {
    refine Module do
      def extend_source_from(chunks, &block)
        location = caller_locations(1, 1).first
        source_chunks = Array(chunks).flat_map(&block)
        class_eval source_chunks.join("\n\n"), location.path, location.lineno
      end
    end
  }

  module ClassMethods
    def has_object(*names, **callbacks)
      extend_source_from(names) do |name|
        const_get object_name = name.to_s.camelize
        "def #{name}; (@associated_objects ||= {})[:#{name}] ||= #{object_name}.new(self); end"
      rescue NameError
        raise "The #{self}::#{object_name} associated object referenced from #{self} doesn't exist"
      end

      extend_source_from(names) do |name|
        callbacks.map do |callback, method|
          "#{callback} { #{name}.#{method == true ? callback : method} }"
        end
      end
    end
  end

  def init_internals
    @associated_objects = nil
    super
  end
end
