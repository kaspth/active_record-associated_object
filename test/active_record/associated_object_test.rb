# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObjectTest < Minitest::Test
  def setup
    super
    @post = Post.first
    @publisher = @post.publisher
  end

  def test_associated_object_alias
    assert_equal @post, @publisher.post
    assert_equal @publisher.post, @publisher.record
  end

  def test_associated_object_integration
    assert_equal @publisher,     Post::Publisher.first
    assert_equal @publisher,     Post::Publisher.find(1)
    assert_equal @publisher,     Post::Publisher.find_by(id: 1)
    assert_equal @publisher,     Post::Publisher.find_by(title: Post.first.title)
    assert_equal @publisher,     Post::Publisher.find_by(author: Author.first)
    assert_equal [ @publisher ], Post::Publisher.where(id: 1)
  end
end
