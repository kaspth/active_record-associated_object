# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "active_record/associated_object"
require "kredis"
require "active_job"
require "global_id"
require "debug"
require "logger"

require "minitest/autorun"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.integer :author_id
  end
end

# Shim what an app integration would look like.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class ApplicationRecord::AssociatedObject < ActiveRecord::AssociatedObject
  include GlobalID::Identification, Kredis::Attributes
end

class Author < ApplicationRecord
  has_many :posts
end

class Post < ApplicationRecord
  belongs_to :author
end

author = Author.create!
author.posts.create! id: 1, title: "First post"

GlobalID.app = "test"

class Post::Publisher < ApplicationRecord::AssociatedObject
  mattr_accessor :performed, default: false

  def publish_later
    PublishJob.perform_later self
  end

  class PublishJob < ActiveJob::Base
    def perform(publisher)
      publisher.performed = true
    end
  end
end
