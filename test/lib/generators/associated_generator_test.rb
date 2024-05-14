require "test_helper"
require "pathname"
require "rails/generators"
require "generators/associated/associated_generator"

class AssociatedGeneratorTest < Rails::Generators::TestCase
  tests AssociatedGenerator
  destination Pathname(__dir__).join("../../../tmp/generators")

  setup :prepare_destination, :create_record_file, :create_record_test_file
  arguments %w[Organization::Seats]

  test "generator runs without errors" do
    assert_nothing_raised { run_generator }
  end

  test "generates an object.rb file" do
    run_generator

    assert_file "app/models/organization/seats.rb", <<~RUBY
      class Organization::Seats < ActiveRecord::AssociatedObject
        extension do
          # Extend Organization here
        end
      end
    RUBY
  end

  test "generates an object_test.rb file" do
    run_generator

    assert_file "test/models/organization/seats_test.rb", /Organization::SeatsTest/
  end

  test "connects record" do
    run_generator

    assert_file "app/models/organization.rb", <<~RUBY
      class Organization
        has_object :seats
      end
    RUBY
  end

  test "raises error if associated record doesn't exist" do
    assert_raise RuntimeError do
      run_generator ["Business::Monkey"]
    end
  end

  private

  def create_record_file
    create_file "app/models/organization.rb", <<~RUBY
      class Organization
      end
    RUBY
  end

  def create_record_test_file
    create_file "test/models/organization_test.rb", <<~RUBY
      require "test_helper"

      class OrganizationTest < ActiveSupport::TestCase
      end
    RUBY
  end

  def create_file(path, content)
    destination_root.join(path).tap { _1.dirname.mkpath }.write content
  end
end
