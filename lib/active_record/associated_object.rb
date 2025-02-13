# frozen_string_literal: true

class ActiveRecord::AssociatedObject
  extend ActiveModel::Naming
  include ActiveModel::Conversion

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

  module Caching
    def cache_key_with_version
      "#{cache_key}-#{cache_version}".tap { _1.delete_suffix!("-") }
    end
    delegate :cache_version, to: :record

    def cache_key
      case
      when !record.cache_versioning?
        raise "ActiveRecord::AssociatedObject#cache_key only supports #{record.class}.cache_versioning = true"
      when new_record?
        "#{model_name.cache_key}/new"
      else
        "#{model_name.cache_key}/#{id}"
      end
    end
  end
  include Caching

  attr_reader :record
  delegate :id, :new_record?, :persisted?, to: :record
  delegate :updated_at, :updated_on, to: :record # Helpful when passing to `fresh_when`/`stale?`
  delegate :transaction, to: :record

  def initialize(record)
    @record = record
  end

  def ==(other)
    other.is_a?(self.class) && id == other.id
  end
end

require_relative "associated_object/version"
require_relative "associated_object/railtie" if defined?(Rails::Railtie)
