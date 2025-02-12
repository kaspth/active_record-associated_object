class ActiveRecord::AssociatedObject
  extend ActiveModel::Naming

  class << self
    def inherited(new_object)
      new_object.associated_via(new_object.module_parent)
    end

    def associated_via(record)
      unless record.respond_to?(:descends_from_active_record?) && record.descends_from_active_record?
        raise ArgumentError, "#{record} isn't a valid namespace; can only associate with ActiveRecord::Base subclasses"
      end

      @record, @attribute_name = record, model_name.element.to_sym
      alias_method record.model_name.element, :record
    end

    attr_reader :record, :attribute_name
    delegate :primary_key, :unscoped, :transaction, to: :record

    def extension(&block)
      record.class_eval(&block)
    end

    def method_missing(method, ...)
      if !record.respond_to?(method) then super else
        record.public_send(method, ...).then do |value|
          value.respond_to?(:each) ? value.map(&attribute_name) : value&.public_send(attribute_name)
        end
      end
    end
    def respond_to_missing?(...) = record.respond_to?(...) || super
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
