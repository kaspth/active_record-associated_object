class AssociatedGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def generate_associated_object
    template "associated.rb", associated_object_file
  end

  def generate_associated_object_test
    template "associated_test.rb", associated_object_test_file
  end

  def connect_associated_object
    raise "Record class '#{record_klass}' does not exist" unless File.exist?(record_file)

    inject_into_class record_file, record_klass do
      indent "has_object :#{singular_name}\n\n"
    end
  end

  private

  def record_file      = "#{destination_root}/app/models/#{record_path}.rb"
  def record_test_file = "#{destination_root}/test/models/#{record_path}_test.rb"

  def associated_object_file      = "#{destination_root}/app/models/#{record_path}/#{associated_object_path}.rb"
  def associated_object_test_file = "#{destination_root}/test/models/#{record_path}/#{associated_object_path}_test.rb"

  # The `:name` argument can handle model names, but associated object class names aren't singularized.
  # So these record and associated_object methods prevent that.
  def record_path  = record_name.downcase.underscore
  def record_klass = record_name.camelize
  def record_name  = name.deconstantize

  def associated_object_path  = associated_object_name.downcase.underscore
  def associated_object_class = associated_object_name.camelize
  def associated_object_name  = name.demodulize
end
