# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails/railtie"
require "kredis"
require "debug"
require "logger"

require "active_record"
require "active_record/associated_object"

require "global_id"
require "active_job"
require "active_job/performs"

require "minitest/autorun"

# Simulate Rails app boot and run the railtie initializers manually.
ActiveRecord::AssociatedObject::Railtie.run_initializers
ActiveSupport.run_load_hooks :after_initialize, Rails::Railtie

Kredis.configurator = Class.new do
  def config_for(name) = { db: "1" }
  def root = Pathname.new(".")
end.new

GlobalID.app = "test"

class ApplicationJob < ActiveJob::Base
end

require_relative "boot/active_record"
require_relative "boot/associated_object"

author = Author.create!
post = author.posts.create! id: 1, title: "First post"
author.comments.create! post: post, body: "First!!!!"

class ActiveSupport::TestCase
  teardown { Kredis.clear_all }
end
