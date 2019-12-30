# Sandstone

A simple Object Relational Model (ORM) for Crystal based on a fork of Sandstone
ORM. This fork includes specific changes for SQLite more flexible "has many through"
relationships, custom column names for foreign keys and more. 

This assumes familiarity with a Rails-style ORM. 

It is a personal fork created to address limitations found in Sandstone. I'm happy
to help with questions and feauters, but it is not even remotely recommended 
for production use. I haven't even gotten around to replacing all the mentions
of Sandstone.

## Installation

Add this library to your projects dependencies along with the driver in
your `shard.yml`.  This can be used with any framework but was originally
designed to work with the amber framework in mind.  This library will work
with kemal or any other framework as well.

WARNING: There's [a bug in shards](https://github.com/crystal-lang/shards/issues/310) 
that prevents renaming of a shard (this is a renamed fork) unless you destroy historical git tags.
For now you'll have to download it and require it using a local path. Note that the 
current version of shards [no longer supports paths starting with tilde](https://github.com/crystal-lang/shards/issues/308) ( `~` ).

```yaml
dependencies:
  sandstone:
    # commented out version that doesn't work with current shards bug.
    #github: masukomi/sandstone
    #version: 0.8.4-sandstone
    path: /absolute/path/to/where/you/cloned/sandstone
  sqlite3:
    github: crystal-lang/crystal-sqlite3

```

Next you will need to create a `config/database.yml`
You can leverage environment variables using `${}` syntax.

```yaml
sqlite:
  database: "sqlite3:./config/${DB_NAME}.db"
```

Or you can set the `DATABASE_URL` environment variable.  This will override the config/database.yml

## Usage

Here is an example using Sandstone ORM Model

```crystal
require "sandstone/adapter/mysql"

class Post < Sandstone::ORM::Base
  adapter mysql
  field name : String
  field body : String
  timestamps # will create and update the created_at and updated_at columns
             # DOES NOT WORK WITH SQLITE (yet)
end
```

You can disable the timestamps for SqlLite since TIMESTAMP is not supported for this database:

```crystal
require "sandstone/adapter/sqlite"

class Comment < Sandstone::ORM::Base
  adapter sqlite
  no_timestamps  # you'll have to manage timestamp columns yourself currently
  table_name post_comments
  field name : String
  field body : String
end
```


### Custom Primary Key

For legacy database mappings, you may already have a table and the primary key is not named `id` or `Int64`.

We have a macro called `primary` to help you out:

```crystal
class Site < Sandstone::ORM::Base
  adapter mysql
  primary custom_id : Int32
  field name : String
end
```

### Custom foreign key
Specify what columns will be called that reference a foreign key for the current
class

```crystal
class Event
  ...
  set_foreign_key event_id
end
```

### Custom default ordering column
Specify what column results will be ordered by by default.

```crystal
class event
  ...
  set_order_column created_at
end
```

### Custom Table Name
Specify the name of your table if it can't simply be pluralized by adding an s.
This is leveraged by other code to support a more flexible table naming system.

```crystal
class Cactus
  table_name cacti
end

```


This will override the default primary key of `id : Int64`.

### SQL

To clear all the rows in the database:

```crystal
Post.clear #truncate the table
```

#### Find All

```crystal
posts = Post.all
if posts
  posts.each do |post|
    puts post.name
  end
end
```

#### Find First

```crystal
post = Post.first
if post
  puts post.name
end
```

#### Find Last 
```crystal
post = Post.last
puts post.name if post
```

#### Find

```crystal
post = Post.find 1
if post
  puts post.name
end
```

#### Find By

```crystal
post = Post.find_by :slug, "example_slug"
if post
  puts post.name
end
```

#### Find or Create
A simplistic find or create. Useful if the object can be created with data in
only one column (other than the `id` column).

```crystal
class Person
  find_or_creatable Person, name

end
```

Allows you to

```
Person.find_or_create_with(names_array)
```

Creates a bunch of people using the names in the array.


#### Insert

```crystal
post = Post.new
post.name = "Sandstone ORM Rocks!"
post.body = "Check this out."
post.save
```

#### Update

```crystal
post = Post.find 1
post.name = "Sandstone Really Rocks!"
post.save
```

#### Delete

```crystal
post = Post.find 1
post.destroy
puts "deleted" unless post
```

### Queries

The where clause will give you full control over your query.

#### All

When using the `all` method, the SQL selected fields will always match the
fields specified in the model.

Always pass in parameters to avoid SQL Injection.  Use a `?`
in your query as placeholder. Checkout the [Crystal DB Driver](https://github.com/crystal-lang/crystal-db)
for documentation of the drivers.

Here are some examples:

```crystal
posts = Post.all("WHERE name LIKE ?", ["Joe%"])
if posts
  posts.each do |post|
    puts post.name
  end
end

# ORDER BY Example
posts = Post.all("ORDER BY created_at DESC")

# JOIN Example
posts = Post.all("JOIN comments c ON c.post_id = post.id
                  WHERE c.name = ?
                  ORDER BY post.created_at DESC",
                  ["Joe"])

```

#### First

It is common to only want the first result and append a `LIMIT 1` to the query.
This is what the `first` method does.

For example:

```crystal
post = Post.first("ORDER BY posts.name DESC")
```

This is the same as:

```crystal
post = Post.all("ORDER BY posts.name DESC LIMIT 1").first
```

### Relationships

#### One to Many

`owned_by` and `has_some` macros provide association handling between objects.


```crystal
class User < Sandstone::ORM::Base
  adapter mysql

  has_some Post

  field email : String
  field name : String
  timestamps
end
```

This will add a `posts` instance method to the user which returns an array of posts.

```crystal
class Post < Sandstone::ORM::Base
  adapter mysql

  owned_by User 
  # optionally specify the foreign key column if it isn't just the lower case 
  # class name followed by _id
  # owned_by User, column: user_id

  field title : String
  timestamps
end
```

You can also have some of X through Y. In this case a `User` has some `Posts`
through the `UserPost` class. The `UserPost` class must, of course, also be
managed by Sandstone.

```
class User
  has_some Post, through: UserPost
  ...
end

class UserPost
  owned_by User, column: user_id
  owned_by Post, column: post_id
end

class Post
  has_some User, through: UserPost
end
```



#### Many to Many

Instead of using a hidden many-to-many table, Sandstone recommends always creating a model for your join tables.  For example, let's say you have many `users` that belong to many `rooms`. We recommend adding a new model called `participants` to represent the many-to-many relationship.

Then you can use the `belongs_to` and `has_many` relationships going both ways.

```crystal
class User < Sandstone::ORM::Base
  has_many :participants

  field name : String
end

class Participant < Sandstone::ORM::Base
  belongs_to :user
  belongs_to :room
end

class Room < Sandstone::ORM::Base
  has_many :participants

  field name : String
end
```


### Callbacks

There is support for callbacks on certain events.

Here is an example:

```crystal
require "sandstone/adapter/pg"

class Post < Sandstone::ORM
  adapter pg

  before_save :upcase_title

  field title : String
  field content : String
  timestamps

  def upcase_title
    if title = @title
      @title = title.upcase
    end
  end
end
```

You can register callbacks for the following events:

#### Create

- before_save
- before_create
- **save**
- after_create
- after_save

#### Update

- before_save
- before_update
- **save**
- after_update
- after_save

#### Destroy

- before_destroy
- **destroy**
- after_destroy












-------

-------

## DEPRECATED original Sandstone ORM functionality
Warning: This code is still present in the codebase only because it hasn't
been deleted yet. It probably still works.... probably.


### One To Many
`belongs_to` and `has_many` macros provide a rails like mapping between Objects.

```crystal
class User < Sandstone::ORM::Base
  adapter mysql

  has_many :posts

  field email : String
  field name : String
  timestamps
end
```

This will add a `posts` instance method to the user which returns an array of posts.

```crystal
class Post < Sandstone::ORM::Base
  adapter mysql

  belongs_to :user

  field title : String
  timestamps
end
```

This will add a `user` and `user=` instance method to the post.

For example:

```crystal
user = User.find 1
user.posts.each do |post|
  puts post.title
end

post = Post.find 1
puts post.user

post.user = user
post.save
```

In this example, you will need to add a `user_id` and index to your posts table:

```mysql
CREATE TABLE posts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  title VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX 'user_id_idx' ON posts (user_id);
```

#### Many to Many

Instead of using a hidden many-to-many table, Sandstone recommends always creating a model for your join tables.  For example, let's say you have many `users` that belong to many `rooms`. We recommend adding a new model called `participants` to represent the many-to-many relationship.

Then you can use the `belongs_to` and `has_many` relationships going both ways.

```crystal
class User < Sandstone::ORM::Base
  has_many :participants

  field name : String
end

class Participant < Sandstone::ORM::Base
  belongs_to :user
  belongs_to :room
end

class Room < Sandstone::ORM::Base
  has_many :participants

  field name : String
end
```

The Participant class represents the many-to-many relationship between the Users and Rooms.

Here is what the database table would look like:

```mysql
CREATE TABLE participants (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  room_id BIGINT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX 'user_id_idx' ON TABLE participants (user_id);
CREATE INDEX 'room_id_idx' ON TABLE participants (room_id);
```

##### has_many through:

As a convenience, we provide a `through:` clause to simplify accessing the many-to-many relationship:

```crystal
class User < Sandstone::ORM::Base
  has_many :participants
  has_many :rooms, through: participants

  field name : String
end

class Participant < Sandstone::ORM::Base
  belongs_to :user
  belongs_to :room
end

class Room < Sandstone::ORM::Base
  has_many :participants
  has_many :users, through: participants

  field name : String
end
```

This will allow you to find all the rooms that a user is in:

```crystal
user = User.first
user.rooms.each do |room|
  puts room.name
end
```

And the reverse, all the users in a room:

```crystal
room = Room.first
room.users.each do |user|
  puts user.name
end
```

### Errors

All database errors are added to the `errors` array used by Sandstone::ORM::Validators with the symbol ':base'

```crystal
post = Post.new
post.save
post.errors[0].to_s.should eq "ERROR: name cannot be null"
```


## Contributing

1. Fork it ( https://github.com/masukomi/sandstone/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


