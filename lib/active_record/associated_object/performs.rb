module ActiveRecord::AssociatedObject::Performs
  begin
    ActiveRecord::AssociatedObject::Job # Attempt a load to see if the app has defined an override.
  rescue NameError
    # TODO: Replace ActiveJob::Base with ApplicationJob
    class ActiveRecord::AssociatedObject::Job < ActiveJob::Base
      def perform(object, method, *arguments, **options)
        object.send(method, *arguments, **options)
      end
    end
  end

  def performs(*methods, **configs, &block)
    if methods.empty?
      apply_performs_to(job, **configs, &block)
    else
      jobs_by_method = methods.index_with { find_or_define_job(detail: _1, superclass: job) }
      jobs_by_method.each_value { |job| apply_performs_to(job, **configs, &block) }

      extend_source_from(jobs_by_method) do |method, job|
        <<~RUBY
          def #{method}_later(*arguments, **options)
            #{job}.perform_later self, :#{method}, *arguments, **options
          end
        RUBY
      end
    end
  end

  def job
    @job ||= find_or_define_job(superclass: ActiveRecord::AssociatedObject::Job)
  end

  private
    def find_or_define_job(detail: nil, superclass:)
      name = "#{record_klass}::#{attribute_name.classify}::#{detail&.classify}Job"
      name.safe_constantize || const_set(name, Class.new(superclass))
    end

    def apply_performs_to(job_class, **configs, &block)
      job_class.class_eval do
        configs.each { public_send(_1, _2) }
        yield if block_given?
      end
    end
end
