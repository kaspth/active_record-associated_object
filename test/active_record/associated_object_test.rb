# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper # TODO: Switch back to Minitest::Test, but need to fix `tagged_logger` NoMethodError.

  def setup
    super
    @post = Post.first
    @publisher = @post.publisher

    @author = Author.first
    @archiver = @author.archiver

    @comment = @author.comments.first
    @rating = @comment.rating
  end

  def test_associated_object_alias
    assert_equal @post, @publisher.post
    assert_equal @publisher.post, @publisher.record

    assert_equal @comment, @rating.comment
    assert_equal @rating.comment, @rating.record
  end

  def test_associated_object_method_missing_extraction
    assert_equal @publisher,     Post::Publisher.first
    assert_equal @publisher,     Post::Publisher.last
    assert_equal @publisher,     Post::Publisher.find(1)
    assert_equal @publisher,     Post::Publisher.find_by(id: 1)
    assert_equal @publisher,     Post::Publisher.find_by(title: Post.first.title)
    assert_equal @publisher,     Post::Publisher.find_by(author: Author.first)
    assert_equal [ @publisher ], Post::Publisher.where(id: 1)

    assert_equal @rating,     Post::Comment::Rating.first
    assert_equal @rating,     Post::Comment::Rating.last
    assert_equal @rating,     Post::Comment::Rating.find([@post, @author])
    assert_equal @rating,     Post::Comment::Rating.find_by(Post::Comment::Rating.primary_key => [[@post.id, @author.id]])
    assert_equal @rating,     Post::Comment::Rating.find_by(body: "First!!!!")
    assert_equal @rating,     Post::Comment::Rating.find_by(author: Author.first)
    assert_equal [ @rating ], Post::Comment::Rating.where(Post::Comment::Rating.primary_key => [[@post.id, @author.id]])
  end

  def test_introspection
    assert_equal Post, @publisher.record_klass
    assert_equal Post, Post::Publisher.record_klass

    assert_equal :publisher, @publisher.attribute_name
    assert_equal :publisher, Post::Publisher.attribute_name

    assert_equal Author, @archiver.record_klass
    assert_equal Author, Author::Archiver.record_klass

    assert_equal :archiver, @archiver.attribute_name
    assert_equal :archiver, Author::Archiver.attribute_name

    assert_equal Post::Comment, @rating.record_klass
    assert_equal Post::Comment, Post::Comment::Rating.record_klass

    assert_equal :rating, @rating.attribute_name
    assert_equal :rating, Post::Comment::Rating.attribute_name
  end

  def test_unscoped_passthrough
    # TODO: lol what's this actually supposed to do? Need to look more into GlobalID.
    # https://github.com/rails/globalid/blob/3ddb0f87fd5c22b3330ab2b4e5c41a85953ac886/lib/global_id/locator.rb#L164
    assert_equal [ @post ], @publisher.class.unscoped
  end

  def test_transaction_passthrough
    assert_equal @post, Post::Publisher.transaction { Post.first }
    assert_equal @post, @publisher.transaction { Post.first }
  end

  def test_primary_key_passthrough
    assert_equal Post.primary_key, Post::Publisher.primary_key
  end

  def test_callback_passing
    @post.update title: "Updated title"
    assert_equal "Updated title", @publisher.captured_title

    @post.destroy
    refute_predicate @post, :destroyed?
    refute_empty Post.all
  end

  def test_ivar_initialization
    # Confirm that it initializes the instance variable to nil
    assert_includes Author.new.instance_variables, :@associated_objects
    assert_nil Author.new.instance_variable_get(:@associated_objects)

    # It still includes the default Rails variables
    assert_equal Post.new.instance_variable_get(:@new_record), true
  end

  def test_kredis_integration
    Time.new(2022, 4, 20, 1).tap do |publish_at|
      @publisher.publish_at.value = publish_at

      assert_equal "post:publishers:1:publish_at", @publisher.publish_at.key
      assert_equal publish_at, @publisher.publish_at.value
    end

    @rating.moderated.mark
    assert_equal "post:comment:ratings:[1, 1]:moderated", @rating.moderated.key
    assert @rating.moderated?
  end

  def test_global_id_integration
    assert_equal "gid://test/Post::Publisher/1", @publisher.to_gid.to_s
    assert_equal @publisher, GlobalID.find(@publisher.to_gid.to_s)

    assert_raises(ActiveRecord::RecordNotFound) { GlobalID::Locator.locate_many([ Post.new(id: 2).publisher.to_gid.to_s ]) }
    assert_equal [ @publisher ], GlobalID::Locator.locate_many([ @publisher.to_gid.to_s ])
    assert_equal [ @publisher ], GlobalID::Locator.locate_many([ @publisher.to_gid.to_s, Post.new(id: 2).publisher.to_gid.to_s ], ignore_missing: true)

    assert_equal "gid://test/Post::Comment::Rating/1/1", @rating.to_gid.to_s
    assert_equal @rating, GlobalID.find(@rating.to_gid.to_s)

    missing_rating = Post::Comment.new(post_id: 2, author_id: 10).rating
    assert_raises(ActiveRecord::RecordNotFound) { GlobalID::Locator.locate_many([ missing_rating.to_gid.to_s ]) }
    assert_equal [ @rating ], GlobalID::Locator.locate_many([ @rating.to_gid.to_s ])
    assert_equal [ @rating ], GlobalID::Locator.locate_many([ @rating.to_gid.to_s, missing_rating.to_gid.to_s ], ignore_missing: true)
  end

  def test_active_job_integration
    @publisher.performed = false

    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ], queue: "important" do
      @publisher.publish_later
    end

    assert @publisher.performed
  end

  def test_calling_method
    assert @rating.great?
  end

  def test_record_klass_extension
    assert_predicate Post::Comment.great.first, :rated_great?
    assert_match /test\/boot\/associated_object/, Post::Comment.instance_method(:rated_great?).source_location.first
  end
end
