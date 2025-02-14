require "test_helper"
require "action_controller"
require "action_view"

class Post::PublishersController < ActionController::Base
  def show
    fresh_when Post::Publisher.find(params[:id])
    head :no_content unless performed?
  end
end

Rails.logger = Logger.new "/dev/null"
Rails.application.middleware.delete ActionDispatch::HostAuthorization

Rails.application.routes.draw do
  namespace(:post) { resources :publishers }
end

class ActiveRecord::AssociatedObject::IntegrationTest < ActionDispatch::IntegrationTest
  self.app = Rails.application
  setup { @post, @publisher = Post.first.then { [_1, _1.publisher] } }

  test "url helper" do
    assert_equal "/post/publishers/#{@post.id}", post_publisher_path(@publisher)
  end

  test "fresh_when" do
    get "/post/publishers/#{@post.id}"
    assert_response :no_content

    get "/post/publishers/#{@post.id}", headers: { HTTP_IF_NONE_MATCH: headers["etag"] }
    assert_response :not_modified
  end
end

class ActiveRecord::AssociatedObject::ViewTest < ActionView::TestCase
  ActionController::Base.cache_store = :memory_store
  include Rails.application.routes.url_helpers

  setup { @post, @publisher = Post.first.then { [_1, _1.publisher] } }

  test "form_with" do
    concat form_with(model: @publisher)
    assert_select "form[action='/post/publishers/#{@post.id}']"
  end

  test "cache" do
    cache(@publisher) { concat "initial" }
    assert_equal "initial", fragment_for(@publisher, {}) { "second" }
  end
end
