# ActiveRecord::AssociatedObject

Associate a Ruby PORO with an Active Record class and have it quack like one. Build and extend your domain model relying on the Active Record association to make it unique.

```ruby
class Post < ActiveRecord::Base
end

# Create a standard PORO, but derive attributes from the Post:: namespace and its primary key.
class Post::Publisher < ActiveRecord::AssociatedObject
  kredis_datetime :publish_at # Kredis integration generates a "post:publisher:<post_id>:publish_at" key.

  def publish_later
    PublishJob.set(wait: publish_at).perform_later self
  end
end

class Post::Publisher::PublishJob < ActiveJob::Base
  def perform(publisher)
     # Automatic integration via GlobalID means you don't have to do `post.publisher`.
    publisher.publish_now
  end
end
```

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add active_record-associated_object

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install active_record-associated_object

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/active_record-associated_object.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
