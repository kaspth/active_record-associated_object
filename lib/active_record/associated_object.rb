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

    # Just a module shim to define instance methods on the record while we're loading our associated class.
    def record
      @associated_record_methods_module ||= Module.new.tap { |mod| record_klass.include mod }
    end

    def extract_one(*names)
      names.each do |name|
        define_singleton_method(name) { |*args, **options, &block| record_klass.send(name, *args, **options, &block)&.public_send(attribute_name) }
      end
    end

    def extract_all(*names)
      names.each do |name|
        define_singleton_method(name) { |*args, **options, &block| record_klass.send(name, *args, **options, &block).map(&attribute_name) }
      end
    end
  end

  extract_one :first, :last, :find, :find_by
  extract_all :where

  attr_reader :record
  delegate :id, to: :record

  def initialize(record)
    @record = record
  end

  def ==(other)
    other.is_a?(self.class) && id == other.id
  end
end
