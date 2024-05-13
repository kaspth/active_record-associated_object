# frozen_string_literal: true

require "test_helper"

class ActiveRecord::AssociatedObject::ObjectAssociationTest < ActiveSupport::TestCase
  test "standard PORO can be accessed" do
    assert_kind_of Post::Mailroom, Post.first.mailroom

    author = Author.first
    assert_kind_of Author::Archiver,       author.archiver
    assert_kind_of Author::Classified,     author.classified
    assert_kind_of Author::Fortifications, author.fortifications
  end

  test "callback passing for standard PORO" do
    Post::Mailroom.touched = false

    Post.first.touch
    assert Post.first.mailroom.touched
  end
end
