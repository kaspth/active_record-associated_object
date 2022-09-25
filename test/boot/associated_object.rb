class Post::Mailroom < Struct.new(:record)
  mattr_accessor :touched, default: false

  def after_touch
    self.touched = true
  end
end

class ApplicationRecord::AssociatedObject < ActiveRecord::AssociatedObject; end

class Post::Publisher < ApplicationRecord::AssociatedObject
  mattr_accessor :performed,      default: false
  mattr_accessor :captured_title, default: nil

  kredis_datetime :publish_at

  performs :publish

  def after_update_commit
    self.captured_title = post.title
  end

  def prevent_errant_post_destroy
    throw :abort
  end

  def publish
    self.performed = true
  end
end
