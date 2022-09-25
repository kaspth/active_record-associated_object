# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper # TODO: Switch back to Minitest::Test, but need to fix `tagged_logger` NoMethodError.

  def setup
    super
    @post = Post.first
    @publisher = @post.publisher
  end

  def test_associated_object_alias
    assert_equal @post, @publisher.post
    assert_equal @publisher.post, @publisher.record
  end

  def test_associated_object_method_missing_extraction
    assert_equal @publisher,     Post::Publisher.first
    assert_equal @publisher,     Post::Publisher.last
    assert_equal @publisher,     Post::Publisher.find(1)
    assert_equal @publisher,     Post::Publisher.find_by(id: 1)
    assert_equal @publisher,     Post::Publisher.find_by(title: Post.first.title)
    assert_equal @publisher,     Post::Publisher.find_by(author: Author.first)
    assert_equal [ @publisher ], Post::Publisher.where(id: 1)
  end

  def test_introspection
    assert_equal Post, @publisher.record_klass
    assert_equal Post, Post::Publisher.record_klass

    assert_equal :publisher, @publisher.attribute_name
    assert_equal :publisher, Post::Publisher.attribute_name
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

  def test_callback_passing
    @post.update title: "Updated title"
    assert_equal "Updated title", @publisher.captured_title

    @post.destroy
    refute_predicate @post, :destroyed?
    refute_empty Post.all
  end

  def test_kredis_integration
    Time.new(2022, 4, 20, 1).tap do |publish_at|
      @publisher.publish_at.value = publish_at

      assert_equal "post:publishers:1:publish_at", @publisher.publish_at.key
      assert_equal publish_at, @publisher.publish_at.value
    end
  end

  def test_global_id_integration
    assert_equal "gid://test/Post::Publisher/1", @publisher.to_gid.to_s
    assert_equal @publisher, GlobalID.find(@publisher.to_gid.to_s)

    assert_raises(ActiveRecord::RecordNotFound) { GlobalID::Locator.locate_many([ Post.new(id: 2).publisher.to_gid.to_s ]) }
    assert_equal [ @publisher ], GlobalID::Locator.locate_many([ @publisher.to_gid.to_s ])
    assert_equal [ @publisher ], GlobalID::Locator.locate_many([ @publisher.to_gid.to_s, Post.new(id: 2).publisher.to_gid.to_s ], ignore_missing: true)
  end

  def test_active_job_integration
    @publisher.performed = false

    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ] do
      @publisher.publish_later
    end

    assert @publisher.performed
  end
end
