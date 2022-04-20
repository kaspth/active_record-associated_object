class ApplicationRecord::AssociatedObject < ActiveRecord::AssociatedObject; end

class Post::Publisher < ApplicationRecord::AssociatedObject
  mattr_accessor :performed, default: false

  kredis_datetime :publish_at

  def publish_later
    PublishJob.perform_later self
  end

  class PublishJob < ActiveJob::Base
    def perform(publisher)
      publisher.performed = true
    end
  end
end
