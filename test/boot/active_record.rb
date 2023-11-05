ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.integer :author_id
  end

  create_table :post_comments, primary_key: [:post_id, :author_id] do |t|
    t.integer :post_id, null: false
    t.integer :author_id, null: false
    t.string :body
  end
end

# Shim what an app integration would look like.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Author < ApplicationRecord
  has_many :posts,    dependent: :destroy
  has_many :comments, dependent: :destroy, class_name: "Post::Comment"

  has_object :archiver
end

class Post < ApplicationRecord
  belongs_to :author
  has_many :comments, dependent: :destroy

  has_object :mailroom,  after_touch: true
  has_object :publisher, after_update_commit: true, before_destroy: :prevent_errant_post_destroy
end

class Post::Comment < ApplicationRecord
  belongs_to :post
  belongs_to :author

  has_object :rating
end
