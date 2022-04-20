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

  def test_unscoped_passthrough
    # TODO: lol what's this actually supposed to do? Need to look more into GlobalID.
    # https://github.com/rails/globalid/blob/3ddb0f87fd5c22b3330ab2b4e5c41a85953ac886/lib/global_id/locator.rb#L164
    assert_equal [ @post ], @publisher.class.unscoped
  end

  def test_record_extension_via_module_proxy
    skip

    Post::Publisher.class_eval do
      def record.heyo = :heyo
    end

    assert_equal :heyo, @publisher.post.heyo
    assert_equal :heyo, Post.first.heyo
  end

  def test_global_id_integration
    assert_equal "gid://test/Post::Publisher/1", @publisher.to_gid.to_s
    assert_equal @publisher, GlobalID.find(@publisher.to_gid.to_s)
  end

  def test_active_job_integration
    @publisher.performed = false

    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ] do
      @publisher.publish_later
    end

    assert @publisher.performed
  end
end
