class ActiveRecord::AssociatedObject
  singleton_class.attr_reader :record_klass, :attribute_name
  delegate :record_klass, :attribute_name, to: :class

  class << self
    def polymorphic? = record_klass.nil?

    def associate_with(record_klass)
      raise ArgumentError, "#{record_klass} isn't valid; can only associate with ActiveRecord::Base subclasses" \
        unless record_klass.respond_to?(:descends_from_active_record?) && record_klass.descends_from_active_record?

      @record_klass   = record_klass
      @attribute_name = to_s.demodulize.underscore.to_sym

      alias_method module_parent_name.demodulize.underscore, :record # `alias_method :post, :record` for a `Post::Publisher`.
    end
    def inherited(klass) = klass.module_parent_name && klass.associate_with(klass.module_parent)

    def extension(&block)
      raise ArgumentError, "calling `extension` on polymorphic Associated Objects isn't supported yet" if polymorphic?
      record_klass.class_eval(&block)
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

require_relative "associated_object/version"
require_relative "associated_object/railtie" if defined?(Rails::Railtie)
