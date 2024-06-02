class ApplicationRecord::AssociatedObject < ActiveRecord::AssociatedObject; end

class Author::Archiver < ApplicationRecord::AssociatedObject; end
# TODO: Replace with Data.define once on Ruby 3.2.
Author::Classified     = Struct.new(:author)
Author::Fortifications = Struct.new(:author)

Author.has_object :archiver, :classified, :fortifications

class Post::Mailroom < Struct.new(:record)
  mattr_accessor :touched, default: false

  def after_touch
    self.touched = true
  end
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

Post.has_object :mailroom,  after_touch: true
Post.has_object :publisher, after_update_commit: true, before_destroy: :prevent_errant_post_destroy

class Post::Comment::Rating < ActiveRecord::AssociatedObject
  extension do
    scope :great, -> { where(body: "First!!!!") }

    def rated_great? = rating.great?
  end

  kredis_flag :moderated

  def great?
    comment.body == "First!!!!"
  end
end

Post::Comment.has_object :rating

# Can locate subclasses by grepping for `< Pricing`
class Pricing < ActiveRecord::AssociatedObject::Polymorphic
  # Here, `record` will return the post for Post::Pricing objects and the comment for Post::Comment::Pricings.

  def something_conditional
    execute_behavior if post?
  end
end

class Post::Pricing < Pricing
  def something_conditional
    # Or just only implement the behavior in one class and thus rely on Polymorphism?
  end
end

class Post::Comment::Pricing < Pricing
  def something_conditional
    # Nothing to do for comment
  end
end

p Pricing.new(Post.new).post? # => true
p Post::Pricing.new(Post.new).post? # => true

p Pricing.new(Post::Comment.new).post? # => false
p Post::Comment::Pricing.new(Post::Comment.new).post? # => false

p Pricing.new(Post::Comment.new).comment? # => true
p Post::Comment::Pricing.new(Post::Comment.new).comment? # => true
