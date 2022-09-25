## [0.3.0] - 2022-09-25

- Add `performs` to help cut down Active Job boilerplate.

  ```ruby
  class Post::Publisher < ActiveRecord::AssociatedObject
    performs :publish, queue_as: :important

    def publish
      …
    end
  end
  ```

  The above is the same as writing:

  ```ruby
  class Post::Publisher < ActiveRecord::AssociatedObject
    class Job < ApplicationJob; end
    class PublishJob < Job
      queue_as :important

      def perform(publisher, *arguments, **options)
        publisher.publish(*arguments, **options)
      end
    end

    def publish_later(*arguments, **options)
      PublishJob.perform_later(self, *arguments, **options)
    end

    def publish
      …
    end
  end
  ```

  See the README for more details.

## [0.2.0] - 2022-04-21

- Require a `has_object` call on the record side to associate an object.

  ```ruby
  class Post < ActiveRecord::Base
    has_object :publisher
  end
  ```

- Allow `has_object` to pass callbacks onto the associated object.

  ```ruby
  class Post < ActiveRecord::Base
    has_object :publisher, after_touch: true, before_destroy: :prevent_errant_post_destroy
  end
  ```

## [0.1.0] - 2022-04-19

- Initial release
