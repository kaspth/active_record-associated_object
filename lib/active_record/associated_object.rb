class ActiveRecord::AssociatedObject
  class << self
    def inherited(klass)
      record_klass   = klass.module_parent
      record_name    = klass.module_parent_name.underscore
      attribute_name = klass.to_s.demodulize.underscore.to_sym

      unless record_klass.respond_to?(:descends_from_active_record?) && record_klass.descends_from_active_record?
        raise ArgumentError, "#{record_klass} isn't valid; can only associate with ActiveRecord::Base subclasses"
      end

      alias_method record_name, :record
      define_singleton_method(:record_klass)   { record_klass }
      define_singleton_method(:attribute_name) { attribute_name }
      delegate :record_klass, :attribute_name, to: :class

      record_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{attribute_name}
          @#{attribute_name} ||= #{klass}.new(self)
        end
      RUBY
    end

    def respond_to_missing?(...) = record_klass.respond_to?(...)
    delegate :unscoped, to: :record_klass

    def method_missing(method, ...)
      record_klass.public_send(method, ...).then do |value|
        value.respond_to?(:each) ? value.map(&attribute_name) : value&.public_send(attribute_name)
      end
    end

    # Just a module shim to define instance methods on the record while we're loading our associated class.
    def record
      @associated_record_methods_module ||= Class.new(record_klass) do
        define_singleton_method :method_added do |meth|
          superclass.define_method(meth, &method(meth))
        end
      end
    end
  end

  attr_reader :record
  delegate :id, to: :record

  def initialize(record)
    @record = record
  end

  def ==(other)
    other.is_a?(self.class) && id == other.id
  end
end
