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
