# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails/railtie"
require "kredis"
require "active_job"
require "global_id"
require "debug"
require "logger"

require "active_record"
require "active_record/associated_object"

require "minitest/autorun"

# Simulate Rails app boot and run the railtie initializers manually.
ActiveRecord::AssociatedObject::Railtie.run_initializers

Kredis.configurator = Class.new { def config_for(name) { db: "1" } end }.new

GlobalID.app = "test"

require_relative "boot/active_record"
require_relative "boot/associated_object"

author = Author.create!
author.posts.create! id: 1, title: "First post"

class ActiveRecord::AssociatedObject::Test < ActiveSupport::TestCase
  def teardown
    super
    Kredis.clear_all
  end
end
