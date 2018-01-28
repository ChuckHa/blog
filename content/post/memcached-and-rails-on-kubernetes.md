---
title: "Kubernetes, Rails and Memcached"
date: 2018-01-28T14:28:14-05:00
tags: ["kubernetes", "rails", "memcached", "dalli"]
draft: true
---

I wanted to use a pool of memcached servers to back my [rails cache][rails-cache]. The [dalli wiki describes a Heroku setup][wiki] that uses environment variables to configure a list of memcached servers. This is exactly what I want when deploying to Kubernetes. Using environment variables allows me to avoid hardcoding the memcached host names into the application configuration code.

However, when I set my `cache_store` to `:dalli_store` rails defaults to the `FileCache`. What the heck? When I use `:mem_cache_store` as [described in guides.rubyonrails.org][rails-cache] the memcached servers variable does not get populated. What the heck?

I read through the rails configuration and application bootstrapping process in order to get the config object just right. The solution I came up with uses the expected environment variable (`MEMCACHE_SERVERS`) but uses the appropriate `cache_store` which is rails 5 friendly.

```
config.cache_store = :mem_cache_store, ENV['MEMCACHE_SERVERS'].split(',')
```

## In Detail

The config object defines `cache_store` as an `attr_accessor` (which means the function `cache_store=` is defined automatically). Here is an example of what we're dealing with:

```
class Config
  attr_accessor :cache
  def initialize
    @cache = ['abc','def']
  end
end

irb(main):015:0> a = Config.new
=> #<Config:0x007f8d9b8a2ac0 @cache=["abc", "def"]>

irb(main):018:0> a.cache = 'hello', 'world'
=> ["hello", "world"]

irb(main):020:0> a.cache
=> ["hello", "world"]
```

Now that we know how the `cache_store` instance variable is defined, we need to know what happens to it.

Rails has a bootstrap process that runs after all the configuration setting happens. Near the beginning of the bootstrap process, [`ActiveSupport::Cache.lookup_store` is invoked][cache-load].

That function uses the [first value in the cache_store array as the lookup symbol][lookup-sym] and the [rest of the array as arguments to the constructor][constructor].

At this point it became clear that `:dalli_store` is not defined and will not be found so we will end up with the [default FileStore][default].

However, if `:mem_cache_store` is used, we can see that the dalli documented environment variable [`MEMCACHE_SERVERS` are no where to be found][no-where].

We end up combining approaches and using the environment variable we expect with the store symbol that rails expects.

## Afterthought

When I first wrote this I used a splat on the memcached servers (with a `*`). But after writing up exactly what happens and tracing the code, I found out I don't need to do that. Blogging at its best.

Also I am not a rails expert and am simply trying to get stuff done with rails. I would love to be shown a better/cleaner/simpler way of solving this if it exists.


[wiki]: https://github.com/petergoldstein/dalli/wiki/Heroku-Configuration
[wiki-variadic]: https://en.wikipedia.org/wiki/Variadic_function
[cachestore]: https://github.com/rails/rails/blob/v5.0.6/actionpack/lib/abstract_controller/caching.rb#L15
[cache-load]: https://github.com/rails/rails/blob/v5.0.6/railties/lib/rails/application/bootstrap.rb#L64
[lookup-sym]: https://github.com/rails/rails/blob/v5.0.6/activesupport/lib/active_support/cache.rb#L55
[constructor]: https://github.com/rails/rails/blob/v5.0.6/activesupport/lib/active_support/cache.rb#L60
[default]: https://github.com/rails/rails/blob/v5.0.6/railties/lib/rails/application/configuration.rb#L43
[no-where]: https://github.com/rails/rails/blob/v5.0.6/activesupport/lib/active_support/cache/mem_cache_store.rb#L76-L91
[rails-cache]: http://guides.rubyonrails.org/v5.0/caching_with_rails.html#activesupport-cache-memcachestore