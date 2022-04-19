class ActiveRecord::AssociatedObject
  class << self
    def inherited(object_name)
      record_klass   = object_name.module_parent
      record_name    = object_name.module_parent_name.underscore.to_sym
      attribute_name = object_name.demodulize.underscore.to_sym

      unless record_klass.is_a?(ActiveRecord::Base)
        raise ArgumentError, "#{record_klass} isn't valid; can only associate with ActiveRecord::Base subclasses"
      end

      alias_method record_name, :record
      define_singleton_method(:record_klass)   { record_klass }
      define_singleton_method(:attribute_name) { attribute_name }
      delegate :record_klass, :attribute_name, to: :class
    end

    # Just a module shim to define instance methods on the record while we're loading our associated class.
    def record
      @associated_record_methods_module ||= Module.new.tap { |mod| record_klass.include mod }
    end

    def find(id)
      record_klass.find(id).public_send(attribute_name)
    end

    def find_by(**attributes)
      record_klass.find_by(**attributes)&.public_send(attribute_name)
    end

    def where(...)
      record_klass.where(...).map(&attribute_name)
    end
  end

  struct :record
  delegate :id, to: :record

  def initialize(record)
    @record = record
  end
end
