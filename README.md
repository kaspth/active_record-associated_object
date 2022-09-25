# ActiveRecord::AssociatedObject

Associate a Ruby PORO with an Active Record class and have it quack like one. Build and extend your domain model relying on the Active Record association to make it unique.

## Usage

```ruby
# app/models/post.rb
class Post < ActiveRecord::Base
  # `has_object` defines a `publisher` method that calls Post::Publisher.new(post).
  has_object :publisher
end

# app/models/post/publisher.rb
class Post::Publisher
  def initialize(post)
    @post = post
  end
end
```

If you want Active Job, GlobalID and Kredis integration you can also have `Post::Publisher` inherit from `ActiveRecord::AssociatedObject`. This extends the standard PORO with details from the `Post::` namespace and the post primary key.

```ruby
# app/models/post/publisher.rb
class Post::Publisher < ActiveRecord::AssociatedObject
  # ActiveRecord::AssociatedObject defines initialize(post) automatically. It's derived from the `Post::` namespace.

  kredis_datetime :publish_at # Kredis integration generates a "post:publishers:<post_id>:publish_at" key.

  # `performs` builds a `Post::Publisher::PublishJob` and routes configs over to it.
  performs :publish, queue_as: :important, discard_on: SomeError do
    retry_on TimeoutError, wait: :exponentially_longer
  end

  def publish
    # `transaction` is syntactic sugar for `post.transaction` here.
    transaction do
      # A `post` method is generated to access the associated post. There's also a `record` alias available.
      post.update! published: true
      post.subscribers.post_published post
    end
  end
end
```

### How `performs` removes Active Job boilerplate

With an associated object like this:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  performs queue_as: :important
  performs :publish
  performs :retract

  def publish
  end

  def retract(reason:)
  end
end
```

is equivalent to:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  # `performs` without a method defines a general job to share between method jobs.
  class Job < ApplicationJob
    queue_as :important
  end

  # Individual method jobs inherit from the `Post::Publisher::Job` defined above.
  class PublishJob < Job
    def perform(publisher, *arguments, **options)
      # GlobalID integration means associated objects can be passed into jobs like Active Records, i.e. we don't have to do `post.publisher`.
      publisher.publish(*arguments, **options)
    end
  end

  class RetractJob < Job
    def perform(publisher, *arguments, **options)
      publisher.retract(*arguments, **options)
    end
  end

  def publish_later(*arguments, **options)
    PublishJob.perform_later(self, *arguments, **options)
  end

  def retract_later(*arguments, **options)
    RetractJob.perform_later(self, *arguments, **options)
  end
end
```

### Passing callbacks onto the associated object

`has_object` accepts a hash of callbacks to pass.

```ruby
class Post < ActiveRecord::Base
  # Callbacks can be passed too to a specific method.
  has_object :publisher, after_touch: true, before_destroy: :prevent_errant_post_destroy

  # The above is the same as writing:
  after_touch { publisher.after_touch }
  before_destroy { publisher.prevent_errant_post_destroy }
end

class Post::Publisher < ActiveRecord::AssociatedObject
  def after_touch
    # Respond to the after_touch on the Post.
  end

  def prevent_errant_post_destroy
    # Passed callbacks can throw :abort too, and in this example prevent post.destroy.
    throw :abort if haha_business?
  end
end
```

## Risks of depending on this gem

This gem is relatively tiny and I'm not expecting more significant changes on it, for right now. It's unofficial and not affiliated with Rails core.

Though it's written and maintained by an ex-Rails core person, so I know my way in and out of Rails and how to safely extend it.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add active_record-associated_object

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install active_record-associated_object

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspth/active_record-associated_object.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
