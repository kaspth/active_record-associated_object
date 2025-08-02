# ActiveRecord::AssociatedObject

Rails applications can end up with models that get way too big, and so far, the
Ruby community response has been Service Objects. But sometimes `app/services`
can turn into another junk drawer that doesn't help you build and make concepts for your Domain Model.

`ActiveRecord::AssociatedObject` takes that head on. Associated Objects are a new domain concept, a context object, that's meant to
help you tease out collaborator objects for your Active Record models.

They're essentially POROs that you associate with an Active Record model to get benefits both in simpler code as well as automatic `app/models` organization.

Let's look at an example. Say you have a `Post` model that encapsulates a blog post in a Content-Management-System:

```ruby
class Post < ApplicationRecord
end
```

You've identified that several things need to happen when a post gets published.
But where does that behavior live; in `Post`? That might get messy.

If we put it in a classic Service Object, we've got access to a `def call` method and that's it — what if we need other methods that operate on the state? And then having `PublishPost` or a similar ad-hoc name in `app/services` can pollute that folder over time.

What if we instead identified a `Publisher` collaborator object, a Ruby class that handles publishing? What if we required it to be placed within `Post::` to automatically help connote the object as belonging to and collaborating with `Post`? Then we'd get `app/models/post/publisher.rb` which guides naming and gives more organization in your app automatically through that convention — and helps prevent a junk drawer from forming.

This is what Associated Objects are! We'd define it like this:

```ruby
# app/models/post/publisher.rb
class Post::Publisher < ActiveRecord::AssociatedObject
end
```

And then you can declare it in `Post`:

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  has_object :publisher
end
```

There isn't anything super special happening yet. Here's essentially what's happening under the hood:

```ruby
class Post::Publisher
  attr_reader :post
  def initialize(post) = @post = post
end

class Post < ApplicationRecord
  def publisher = (@associated_objects ||= {})[:publisher] ||= Post::Publisher.new(self)
end
```

Note: due to Ruby's Object Shapes, we use a single `@associated_objects` instance variable that's assigned to `nil` on `Post.new`. This prevents Active Record's from ballooning into many different shapes in Ruby's internals.
We've fixed this so you don't need to care, but this is what's happening.

> [!TIP]
> `has_object` only requires a namespace and an initializer that takes a single argument. The above `Post::Publisher` is perfectly valid as an Associated Object — same goes for `class Post::Publisher < Data.define(:post); end`.

> [!TIP]
> You can pass multiple names too: `has_object :seats, :entitlements, :publisher, :classified, :fortification`. I recommend `-s`, `-[i]er`, `-[i]ed` and `-ion` as the general naming conventions for your Associated Objects.

> [!TIP]
> Plural Associated Object names are also supported: `Account.has_object :seats` will look up `Account::Seats`.

> [!TIP]
> For certain names you may want to define an acronym like so:
>
> ```ruby
> # config/initializers/inflections.rb
> ActiveSupport::Inflector.inflections(:en) do |inflect|
>  inflect.acronym "OAuth" # ‘oauth’ → ‘OAuth’
> end
> ```
>
> Then `has_object :oauth_scopes` will look up `OAuthScopes`, instead of `OauthScopes`.

See how we're always expecting a link to the model, here `post`?

Because of that, you can rely on `post` from the associated object:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  def publish
    # `transaction` is syntactic sugar for `post.transaction` here.
    transaction do
      post.update! published: true
      post.subscribers.post_published post

      # There's also a `record` alias available if you prefer the more general reading version:
      # record.update! published: true
      # record.subscribers.post_published record
    end
  end
end
```

### See Associated Objects in action

#### RubyEvents.org

The https://www.rubyevents.org team has been using Associated Objects to clarify the boundaries of their Active Records and collaborator Associated Objects.

See the usage in the source here:

- [`ActiveRecord::AssociatedObject` instances](https://github.com/search?q=repo%3Arubyevents%2Frubyevents%20ActiveRecord%3A%3AAssociatedObject&type=code)
- [`has_object` calls](https://github.com/search?q=repo%3Arubyevents%2Frubyevents+has_object&type=code)

#### Flipper

The team at [Flipper](https://www.flippercloud.io) used Associated Objects to help keep their new billing structure clean.

You can see real life examples in these blog posts:

- [Organizing Rails Code with ActiveRecord Associated Objects](https://garrettdimon.com/journal/posts/organizing-rails-code-with-activerecord-associated-objects)
- [Data Modeling Entitlements and Pricing for SaaS Applications](https://garrettdimon.com/journal/posts/data-modeling-saas-entitlements-and-pricing)

If your team is using Associated Objects, we're more than happy to feature any write ups here.

### Use the generator to help write Associated Objects

To set up the `Post::Publisher` from above, you can call `bin/rails generate associated Post::Publisher`.

See `bin/rails generate associated --help` for more info.

### Forwarding callbacks onto the associated object

To further help illustrate how your collaborator Associated Objects interact with your domain model, you can forward callbacks.

Say we wanted to have our `publisher` automatically publish posts after they're created. Or we need to refresh a publishing after a post has been touched. Or what if we don't want posts to be destroyed if they're published due to HAHA BUSINESS rules?

So `has_object` can state this and forward those callbacks onto the Associated Object:

```ruby
class Post < ActiveRecord::Base
  # Passing `true` forwards the same name, e.g. `after_touch`.
  has_object :publisher, after_touch: true, after_create_commit: :publish,
    before_destroy: :prevent_errant_post_destroy

  # The above is the same as writing:
  after_create_commit { publisher.publish }
  after_touch { publisher.after_touch }
  before_destroy { publisher.prevent_errant_post_destroy }
end

class Post::Publisher < ActiveRecord::AssociatedObject
  def publish
  end

  def after_touch
    # Respond to the after_touch on the Post.
  end

  def prevent_errant_post_destroy
    # Passed callbacks can throw :abort too, and in this example prevent post.destroy.
    throw :abort if haha_business?
  end
end
```

### Extending the Active Record from within the Associated Object

Since `has_object` eager-loads the Associated Object class, you can also move
any integrating code into the Associated Object.

If you've got a few extensions, you can use `record` to access the Active Record class:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  record.has_many :contracts, dependent: :destroy # `record` returns `Post` here.
end
```

Alternatively, if you have many extensions, use the `extension` block:

> [!NOTE]
> Technically, `extension` is just `Post.class_eval` but with syntactic sugar.

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  extension do
    # Here we're within Post and can extend it:
    has_many :contracts, dependent: :destroy do
      def signed? = all?(&:signed?)
    end

    def self.with_contracts = includes(:contracts)

    after_create_commit :publish_later, if: -> { contracts.signed? }

    # An integrating method that operates on `publisher`.
    private def publish_later = publisher.publish_later
  end
end
```

This is meant as an alternative to having a wrapping `ActiveSupport::Concern` in yet-another file like this:

```ruby
class Post < ApplicationRecord
  include Published
end

# app/models/post/published.rb
module Post::Published
  extend ActiveSupport::Concern

  included do
    has_many :contracts, dependent: :destroy do
      def signed? = all?(&:signed?)
    end

    has_object :publisher
    after_create_commit :publish_later, if: -> { contracts.signed? }
  end

  class_methods do
    def with_contracts = includes(:contracts)
  end

  # An integrating method that operates on `publisher`.
  private def publish_later = publisher.publish_later
end
```

> [!NOTE]
> Notice how in the `extension` version you don't need to:
>
> - have a naming convention for Concerns and where to place them.
> - look up two files to read the feature (the concern and the associated object).
> - wrap integrating code in an `included` block.
> - wrap class methods in a `class_methods` block.

### Primary Benefit: Organization through Convention

The primary benefit for right now is that by focusing the concept of namespaced Collaborator Objects through Associated Objects, you will start seeing them when you're modelling new features and it'll change how you structure and write your apps.

This is what [@natematykiewicz](https://github.com/natematykiewicz) found when they started using the gem (we'll get to `ActiveJob::Performs` soon):

> We're running `ActiveRecord::AssociatedObject` and `ActiveJob::Performs` (via the associated object) in 3 spots in production so far. It massively improved how I was architecting a new feature. I put a PR up for review and a coworker loved how organized and easy to follow the large PR was because of those 2 gems. I'm now working on another PR in our app where I'm using them again. I keep seeing use-cases for them now. I love it. Thank you for these gems!
>
> Anyone reading this, if you haven't checked them out yet, I highly recommend it.

And about a month later it was still holding up:

> Just checking in to say we've added like another 4 associated objects to production since my last message. `ActiveRecord::AssociatedObject` + `ActiveJob::Performs` is like a 1-2 punch super power. I'm a bit surprised that this isn't Rails core to be honest. I want to migrate so much of our code over to this. It feels much more organized and sane. Then my app/jobs folder won't have much in it because most jobs will actually be via some associated object's _later method. app/jobs will then basically be cron-type things (deactivate any expired subscriptions).

Here's what [@nshki](https://github.com/nshki) found when they tried it:

> Spent some time playing with [@kaspth](https://github.com/kaspth)'s `ActiveRecord::AssociatedObject` and `ActiveJob::Performs` and wow! The conventions these gems put in place help simplify a codebase drastically. I particularly love `ActiveJob::Performs`—it helped me refactor out all `ApplicationJob` classes I had and keep important context in the right domain model.

Let's look at testing, then we'll get to passing these POROs to jobs like the quotes mentioned!

### Testing Associated Objects

Follow the `app/models/post.rb` and `app/models/post/publisher.rb` naming structure in your tests and add `test/models/post/publisher_test.rb`.

Then test it like any other object:

```ruby
# test/models/post/publisher_test.rb
class Post::PublisherTest < ActiveSupport::TestCase
  # You can use Fixtures/FactoryBot to get a `post` and then extract its `publisher`:
  setup { @publisher = posts(:one).publisher }
  setup { @publisher = FactoryBot.build(:post).publisher }

  test "publish updates the post" do
    @publisher.publish
    assert @publisher.post.reload.published?
  end
end
```

### Active Model integration

Associated Objects quack like `ActiveModel`s because we:

- [`extend ActiveModel::Naming`](https://api.rubyonrails.org/classes/ActiveModel/Naming.html)
- [`include ActiveModel::Conversion`](https://api.rubyonrails.org/classes/ActiveModel/Conversion.html)

This means you can pass them to helpers like `form_with` and route helpers like `url_for` too.

> [!NOTE]
> We don't `include ActiveModel::Model` since we don't need `assign_attributes` and validations really.

```ruby
# app/controllers/post/publishers_controller.rb
class Post::PublishersController < ApplicationController
  before_action :set_publisher

  def new
  end

  def create
    @publisher.publish params.expect(publisher: :toast)
    redirect_back_or_to root_url, notice: "Out it goes!"
  end

  private
    def set_publisher
      # Associated Objects are POROs, so behind the scenes we're really doing `Post.find(…).publisher`.
      @publisher = Post::Publisher.find(params[:id])
    end
end
```

And then on the view side, you can pass it into `form_with`:

```erb
<%# app/views/post/publishers/new.html.erb %>
<%# Here `form_with` calls `url_for(@publisher)` which calls `post_publisher_path(@publisher)`. %>
<%= form_with model: @publisher do |form| %>
  <%= form.text_field :toast %>
  <%= form.submit "Publish with toast" %>
<% end %>
```

Finally, the routing is pretty standard fare:

```ruby
namespace :post do
  resources :publishers
end
```

#### Rendering Associated Objects

Associated Objects respond to `to_partial_path`, so you can pass them directly to `render`.

We're using Rails' conventions here, so view paths look like this:

```erb
<%# With a Post::Publisher, this renders app/views/post/publishers/_publisher.html.erb %>
<%= render publisher %>

<%# With a Post::Comment::Rating, this renders app/views/post/comment/ratings/_rating.html.erb %>
<%= render rating %>
```

We've also got full support for fragment caching, so this is possible:

```erb
<%# app/views/post/publishers/_publisher.html.erb %>
<%= cache publisher do %>
  <%# More publishing specific view logic. %>
<% end %>
```

> [!NOTE]
> We only support recyclable cache keys which has been the default since Rails 5.2.
> This means the Active Record you associate with must have `SomeModel.cache_versioning = true` enabled.
>
> Associated Objects respond to `cache_key`, `cache_version` and `cache_key_with_version` like Active Records.

### Polymorphic Associated Objects

If you want to share logic between associated objects, you can do so via standard Ruby modules:

```ruby
# app/models/pricing.rb
module Pricing
  # If you need to share an `extension` across associated objects you can override `Module::included` like this:
  def self.included(object) = object.extension do
    # Add common integration methods onto `Account`/`User` when the module is included.
    # See the `extension` block in the `Extending` section above for an example.
  end

  def price_set?
    # Instead of referring to `account` or `user`, use the `record` method to target either.
    record.price_cents.positive?
  end
end

# app/models/account/pricing.rb
class Account::Pricing < ActiveRecord::AssociatedObject
  include ::Pricing
end

# app/models/user/pricing.rb
class User::Pricing < ActiveRecord::AssociatedObject
  include ::Pricing
end
```

Now we can call `account.pricing.price_set?` & `user.pricing.price_set?`.

> [!NOTE]
> Polymorphic Associated Objects are definitely a more advanced topic,
> so you need to know your Ruby module hierarchy and how to track what `self` changes to fairly well.

#### Using `ActiveSupport::Concern` as an alternative

If you prefer the look of Active Support concerns, here's the equivalent to the above Ruby module:

```ruby
# app/models/pricing.rb
module Pricing
  extend ActiveSupport::Concern

  included do
    extension do
      # Add common integration methods onto `Account`/`User` when the concern is included.
    end
  end

  def price_set?
    # Instead of referring to `account` or `user`, use the `record` method to target either.
    record.price_cents.positive?
  end
end
```

Active Support concerns have some extra features that standard Ruby modules don't, like support for deeply-nested concerns and `class_methods do`.

In this case, if you're reaching for those, you're probably building something too intricate and potentially brittle.

### Active Job integration via GlobalID

Associated Objects include `GlobalID::Identification` and have automatic Active Job serialization support that looks like this:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  class PublishJob < ApplicationJob
    def perform(publisher) = publisher.publish
  end

  def publish_later
    PublishJob.perform_later self # We're passing this PORO to the job!
  end

  def publish
    # …
  end
end
```

> [!NOTE]
> Internally, Active Job serializes Active Records as GlobalIDs. Active Record also includes `GlobalID::Identification`, which requires the `find` and `where(id:)` class methods.
>
> We've added `Post::Publisher.find` & `Post::Publisher.where(id:)` that calls `Post.find(id).publisher` and `Post.where(id:).map(&:publisher)` respectively.

This pattern of a job `perform` consisting of calling an instance method on a sole domain object is ripe for a convention, here's how to do that.

#### Remove Active Job boilerplate with `performs`

If you also bundle [`active_job-performs`](https://github.com/kaspth/active_job-performs) in your Gemfile like this:

```ruby
gem "active_job-performs"
gem "active_record-associated_object"
```

Every Associated Object (and Active Records too) now has access to the `performs` macro, so you can do this:

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

which spares you writing all this:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  # `performs` without a method defines a general job to share between method jobs.
  class Job < ApplicationJob
    queue_as :important
  end

  # Individual method jobs inherit from the `Post::Publisher::Job` defined above.
  class PublishJob < Job
    # Here's the GlobalID integration again, i.e. we don't have to do `post.publisher`.
    def perform(publisher, *, **) = publisher.publish(*, **)
  end

  class RetractJob < Job
    def perform(publisher, *, **) = publisher.retract(*, **)
  end

  def publish_later(*, **) = PublishJob.perform_later(self, *, **)
  def retract_later(*, **) = RetractJob.perform_later(self, *, **)
end
```

Note: you can also pass more complex configuration like this:

```ruby
performs :publish, queue_as: :important, discard_on: SomeError do
  retry_on TimeoutError, wait: :exponentially_longer
end
```

See [the `ActiveJob::Performs` README](https://github.com/kaspth/active_job-performs) for more details.

### Automatic Kredis integration

We've got automatic Kredis integration for Associated Objects, so you can use any `kredis_*` type just like in Active Record classes:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  kredis_datetime :publish_at # Uses a namespaced "post:publishers:<post_id>:publish_at" key.
end
```

> [!NOTE]
> Under the hood, this reuses the same info we needed for automatic Active Job support. Namely, the Active Record class, here `Post`, and its `id`.

### Namespaced models

If you have a namespaced Active Record like this:

```ruby
# app/models/post/comment.rb
class Post::Comment < ApplicationRecord
  belongs_to :post
  belongs_to :creator, class_name: "User"

  has_object :rating
end
```

You can define the associated object in the same way it was done for `Post::Publisher` above, within the `Post::Comment` namespace:

```ruby
# app/models/post/comment/rating.rb
class Post::Comment::Rating < ActiveRecord::AssociatedObject
  def good?
    # A `comment` method is generated to access the associated comment. There's also a `record` alias available.
    comment.creator.subscriber_of? comment.post.creator
  end
end
```

And then test it in `test/models/post/comment/rating_test.rb`:

```ruby
class Post::Comment::RatingTest < ActiveSupport::TestCase
  setup { @rating = posts(:one).comments.first.rating }
  setup { @rating = FactoryBot.build(:post_comment).rating }

  test "pretty, pretty, pretty, pretty good" do
    assert @rating.good?
  end
end
```

### Composite primary keys

We support Active Record models with composite primary keys out of the box.

Just setup the associated objects like the above examples and you've got GlobalID/Active Job and Kredis support automatically.

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
