class Post::Mailroom < Struct.new(:record)
  mattr_accessor :touched, default: false

  def after_touch
    self.touched = true
  end
end

class ApplicationRecord::AssociatedObject < ActiveRecord::AssociatedObject; end

class Author::Archiver < ApplicationRecord::AssociatedObject
end

class Post::Publisher < ApplicationRecord::AssociatedObject
  mattr_accessor :performed,      default: false
  mattr_accessor :captured_title, default: nil

  kredis_datetime :publish_at

  performs queue_as: :not_really_important
  performs :publish, queue_as: :important, discard_on: ActiveJob::DeserializationError

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

class Post::Comment::Rating < ActiveRecord::AssociatedObject
  kredis_flag :moderated

  def great?
    # TODO: Fix namespaced records generating a :"post/comments" alias instead of `post_comment` or `comment`
    record.body == "First!!!!"
  end
end
