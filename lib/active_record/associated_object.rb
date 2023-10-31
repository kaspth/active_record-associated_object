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
    end

    def respond_to_missing?(...) = record_klass.respond_to?(...) || super
    delegate :unscoped, :transaction, :primary_key, to: :record_klass

    def method_missing(method, ...)
      if !record_klass.respond_to?(method) then super else
        record_klass.public_send(method, ...).then do |value|
          value.respond_to?(:each) ? value.map(&attribute_name) : value&.public_send(attribute_name)
        end
      end
    end
  end

  attr_reader :record
  delegate :id, :transaction, to: :record

  def initialize(record)
    @record = record
  end

  def ==(other)
    other.is_a?(self.class) && id == other.id
  end
end

require_relative "associated_object/railtie" if defined?(Rails::Railtie)
