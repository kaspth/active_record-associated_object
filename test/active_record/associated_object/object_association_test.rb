# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObject::ObjectAssociationTest < Minitest::Test
  def setup
    super
    @post = Post.first
  end

  def test_standard_PORO_can_be_accessed
    assert_kind_of Post::Mailroom, @post.mailroom
  end

  def test_callback_passing_for_standard_PORO
    Post::Mailroom.touched = false

    @post.touch
    assert @post.mailroom.touched
  end
end
