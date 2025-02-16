# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @post = Post.first
    @publisher = @post.publisher

    @author = Author.first
    @archiver = @author.archiver

    @comment = @author.comments.first
    @rating = @comment.rating
  end

  test "associated object alias" do
    assert_equal @post, @publisher.post
    assert_equal @publisher.post, @publisher.record

    assert_equal @comment, @rating.comment
    assert_equal @rating.comment, @rating.record
  end

  test "associated object method missing extraction" do
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

  test "introspection" do
    assert_equal Post, Post::Publisher.record
    assert_equal :publisher, Post::Publisher.attribute_name

    assert_equal Author, Author::Archiver.record
    assert_equal :archiver, Author::Archiver.attribute_name

    assert_equal Post::Comment, Post::Comment::Rating.record
    assert_equal :rating, Post::Comment::Rating.attribute_name
  end

  test "unscoped passthrough" do
    # TODO: lol what's this actually supposed to do? Need to look more into GlobalID.
    # https://github.com/rails/globalid/blob/3ddb0f87fd5c22b3330ab2b4e5c41a85953ac886/lib/global_id/locator.rb#L164
    assert_equal [ @post ], @publisher.class.unscoped
  end

  test "transaction passthrough" do
    assert_equal @post, Post::Publisher.transaction { Post.first }
    assert_equal @post, @publisher.transaction { Post.first }
  end

  test "primary_key passthrough" do
    assert_equal Post.primary_key, Post::Publisher.primary_key
  end

  test "callback forwarding" do
    @post.update title: "Updated title"
    assert_equal "Updated title", @publisher.captured_title

    @post.destroy
    refute_predicate @post, :destroyed?
    refute_empty Post.all
  end

  test "initialization's instance variables" do
    # Confirm that it initializes the instance variable to nil
    assert_includes Author.new.instance_variables, :@associated_objects
    assert_nil Author.new.instance_variable_get(:@associated_objects)

    # It still includes the default Rails variables
    assert_equal Post.new.instance_variable_get(:@new_record), true
  end

  test "active model conversion integration" do
    assert_equal @publisher, @publisher.to_model
    assert_equal [@post.id], @publisher.to_key
    assert_equal @post.id.to_s, @publisher.to_param
    assert_equal "post/publishers/publisher", @publisher.to_partial_path

    assert_equal @rating, @rating.to_model
    assert_equal @comment.id, @rating.to_key
    assert_equal @comment.id.join("-"), @rating.to_param
    assert_equal "post/comment/ratings/rating", @rating.to_partial_path
  end

  test "cache_key integration" do
    assert_equal "post/publishers/new", Post.new.publisher.cache_key
    assert_equal "post/publishers/#{@post.id}", @publisher.cache_key

    assert_match /\d+/, @publisher.cache_version
    assert_equal @post.cache_version, @publisher.cache_version
    assert_match %r(post/publishers/#{@post.id}-\d+), @publisher.cache_key_with_version

    @post.with updated_at: nil do
      assert_equal "post/publishers/#{@post.id}", @publisher.cache_key_with_version
    end


    assert_equal "post/comment/ratings/new", Post::Comment.new.rating.cache_key
    assert_equal "post/comment/ratings/#{@comment.id}", @rating.cache_key

    assert_match /\d+/, @rating.cache_version
    assert_equal @comment.cache_version, @rating.cache_version
    assert_match %r(post/comment/ratings/.*?-\d+), @rating.cache_key_with_version

    @comment.with updated_at: nil do
      assert_equal "post/comment/ratings/#{@comment.id}", @rating.cache_key_with_version
    end
  end

  test "cache_key integration without cache_versioning" do
    previous_versioning, Post.cache_versioning = Post.cache_versioning, false
    error = assert_raises { @publisher.cache_key }
    assert_match /cache_key.*?Post.cache_versioning = true/, error.message
  ensure
    Post.cache_versioning = previous_versioning
  end

  test "kredis integration" do
    Time.new(2022, 4, 20, 1).tap do |publish_at|
      @publisher.publish_at.value = publish_at

      assert_equal "post:publishers:1:publish_at", @publisher.publish_at.key
      assert_equal publish_at, @publisher.publish_at.value
    end

    @rating.moderated.mark
    assert_equal "post:comment:ratings:[1, 1]:moderated", @rating.moderated.key
    assert @rating.moderated?
  end

  test "global_id integration" do
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

  test "Active Job integration" do
    @publisher.performed = false

    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ], queue: "important" do
      @publisher.publish_later
    end

    assert @publisher.performed
  end

  test "calling method" do
    assert @rating.great?
  end

  test "record_klass extension" do
    assert_predicate Post::Comment.great.first, :rated_great?
    assert_match /test\/boot\/associated_object/, Post::Comment.instance_method(:rated_great?).source_location.first
  end
end
