module ActiveRecord::AssociatedObject::Performs
  def performs(method = nil, **configs, &block)
    @job ||= safe_define("Job") { ApplicationJob }

    if method.nil?
      apply_performs_to(@job, **configs, &block)
    else
      job = safe_define("#{method}_job".classify) { @job }
      apply_performs_to(job, **configs, &block)

      job.class_eval <<~RUBY, __FILE__, __LINE__ + 1 unless job.instance_method(:perform).owner == job
        def perform(object, *arguments, **options)
          object.#{method}(*arguments, **options)
        end
      RUBY

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{method}_later(*arguments, **options)
          #{job}.perform_later(self, *arguments, **options)
        end
      RUBY
    end
  end

  private
    def safe_define(name)
      name.safe_constantize || const_set(name, Class.new(yield))
    end

    def apply_performs_to(job_class, **configs, &block)
      job_class.class_eval do
        configs.each { public_send(_1, _2) }
        yield if block_given?
      end
    end
end
