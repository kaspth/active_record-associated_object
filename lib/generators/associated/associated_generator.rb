class AssociatedGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def generate_associated_object_files
    template "associated.rb",      "app/models/#{name.underscore}.rb"
    template "associated_test.rb", "test/models/#{name.underscore}_test.rb"
  end

  def connect_associated_object
    record_file = "#{destination_root}/app/models/#{record_path}.rb"
    raise "Record class '#{record_klass}' does not exist" unless File.exist?(record_file)

    inject_into_class record_file, record_klass do
      optimize_indentation "has_object :#{associated_object_path}", 2
    end
  end

  private

  # The `:name` argument can handle model names, but associated object class names aren't singularized.
  # So these record and associated_object methods prevent that.
  def record_path  = record_klass.downcase.underscore
  def record_klass = name.deconstantize

  def associated_object_path  = associated_object_class.downcase.underscore
  def associated_object_class = name.demodulize
end
