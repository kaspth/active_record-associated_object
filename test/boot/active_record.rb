ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT) if ENV["VERBOSE"] || ENV["CI"]

ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.integer :author_id
    t.timestamps
  end

  create_table :post_comments, primary_key: [:post_id, :author_id] do |t|
    t.integer :post_id, null: false
    t.integer :author_id, null: false
    t.string :body
    t.timestamps
  end
end

# Shim what an app integration would look like.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  self.cache_versioning = true # Rails sets this during application booting, so we need to do it manually here.
end

class Author < ApplicationRecord
  has_many :posts,    dependent: :destroy
  has_many :comments, dependent: :destroy, class_name: "Post::Comment"
end

class Post < ApplicationRecord
  belongs_to :author
  has_many :comments, dependent: :destroy
end

class Post::Comment < ApplicationRecord
  belongs_to :post
  belongs_to :author
end
