class ActiveRecord::AssociatedObject::Railtie < Rails::Railtie
  initializer "integrations.include" do
    ActiveRecord::AssociatedObject.include Kredis::Attributes       if defined?(Kredis)
    ActiveRecord::AssociatedObject.include GlobalID::Identification if defined?(GlobalID)
  end
end
