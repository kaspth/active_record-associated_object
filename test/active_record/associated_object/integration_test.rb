require "test_helper"
require "action_view"

class ActiveRecord::AssociatedObject::IntegrationTest < ActionView::TestCase
  Rails.application.routes.draw do
    namespace :post do
      resources :publishers
    end
  end

  include Rails.application.routes.url_helpers

  ActionController::Base.cache_store = :memory_store

  setup do
    @post = Post.first
    @publisher = @post.publisher
  end

  test "url helper" do
    assert_equal "/post/publishers/#{@post.id}", post_publisher_path(@publisher)
  end

  test "form_with" do
    concat form_with(model: @publisher)
    assert_select "form[action='/post/publishers/#{@post.id}']"
  end

  test "cache" do
    cache(@publisher) { concat "initial" }
    assert_equal "initial", fragment_for(@publisher, {}) { "second" }
  end
end
