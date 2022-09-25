module ActiveRecord::AssociatedObject::Performs
  def performs(method = nil, **configs, &block)
    job = method ? safe_define_method_job(method) : job
    apply_performs_to(job, **configs, &block)

    class_eval <<~RUBY, __FILE__, __LINE__ + 1 if method
      def #{method}_later(*arguments, **options)
        #{job}.perform_later(self, *arguments, **options)
      end
    RUBY
  end

  def job
    @job ||= safe_define("Job") { ApplicationJob }
  end

  private
    def safe_define_method_job(method)
      safe_define("#{method}_job".classify) { job }.tap do |job|
        job.class_eval <<~RUBY, __FILE__, __LINE__ + 1 unless job.instance_method(:perform).owner == job
          def perform(object, *arguments, **options)
            object.#{method}(*arguments, **options)
          end
        RUBY
      end
    end

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
