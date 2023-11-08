class ActiveRecord::AssociatedObject::Railtie < Rails::Railtie
  initializer "integrations.include" do
    config.after_initialize do
      ActiveRecord::AssociatedObject.include Kredis::Attributes       if defined?(Kredis)
      ActiveRecord::AssociatedObject.include GlobalID::Identification if defined?(GlobalID)
    end
  end

  initializer "object_association.setup" do
    ActiveSupport.on_load :active_job do
      require "active_job/performs"
      ActiveRecord::AssociatedObject.extend ActiveJob::Performs
    rescue LoadError
      # We haven't bundled active_job-performs, so we're continuing without it.
    end

    ActiveSupport.on_load :active_record do
      require "active_record/associated_object/object_association"
      extend ActiveRecord::AssociatedObject::ObjectAssociation
    end
  end
end
