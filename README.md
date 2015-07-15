# Amzon Orders

A collection of Rake tasks for scraping _Amazon.com_ and fetching info about your order history. Useful for determining stats about your purchase habits or automatic fetching of open order status like delivery dates and tracking numbers. Data is stored in a SQLite database and ActiveRecord adapters are provided.

## Install

```bash
git clone https://github.com/chrisb/amazon-orders.git
cd amazon-orders
bundle
bundle exec rake orders:fetch
```

## Usage

Once you've imported your orders, you can print a nicely-formatted table of some interesting stats with `rake stats`.

To update your database, just run `rake orders:fetch` again. By default the task will only update orders that are more than 18 hours old.

## Advanced Usage

The following Rake tasks are available:

| Task Name | Description |
| ------------- | ----------- |
| `rake db:migrate` | Ensure the DB schema is up-to-date.
| `rake db:reset` | Wipe all local order data.
| `rake orders:fetch` | Log in to Amazon.com and fetch all orders in your history.
| `rake config:generate` | Generate a `config/account.yml` file with your Amazon.com credentials.
| `rake stats` | Display some interesting stats about your order history.
| `rake console` | Open an interactive console with the environment loaded (helpful if you want run your own queries or poke around your data).

## Contributing

Send me a pull request; currently there are no tests, sorry.

There are a whole bunch of things I'd like to do with this, but I don't have much time presently, so who knows how this project will shape up.

## Authors

[Several people](https://github.com/chrisb/amazon-orders/graphs/contributors) have contributed to this project.

## License

[MIT License](https://github.com/chrisb/amazon-orders/blob/master/LICENSE). Copyright 2009-2015 Chris Bielinski.
