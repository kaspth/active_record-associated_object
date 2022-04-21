module ActiveRecord::AssociatedObject::ObjectAssociation
  def has_object(*names)
    methods = names.map do |name|
      "def #{name}; @#{name} ||= #{self.name}::#{name.to_s.classify}.new(self); end"
    end

    class_eval methods.join("\n\n"), __FILE__, __LINE__ + 1
  end
end
