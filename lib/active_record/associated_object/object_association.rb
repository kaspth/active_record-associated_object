module ActiveRecord::AssociatedObject::ObjectAssociation
  using Module.new {
    refine Module do
      def extend_source_from(chunks, &block)
        location = caller_locations(1, 1).first
        source_chunks = Array(chunks).flat_map(&block)
        class_eval source_chunks.join("\n\n"), location.path, location.lineno
      end
    end
  }

  def has_object(*names, **callbacks)
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
