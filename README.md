# Amazon Orders

A collection of Rake tasks for scraping _Amazon.com_ and fetching info about your order history. Useful for determining stats about your purchase habits or automatic fetching of open order status like delivery dates and tracking numbers. 

Data is stored in a SQLite database and ActiveRecord adapters are provided.

## Install

```bash
git clone https://github.com/chrisb/amazon-orders.git
cd amazon-orders
bundle
bundle exec rake orders:fetch
```

## Usage

Once you've imported your orders (it can take a while!), you can display a nicely-formatted table of some interesting stats with `rake stats`. 

You'll get output that looks something like this:

```bash
$  rake stats

+-----------------------------------+----------------------------+
|                     Your Amazon.com Stats                      |
+-----------------------------------+----------------------------+
| Customer Since                    | April 2007 (about 8 years) |
| Total Orders                      | 123                        |
| Amount Spent                      | $1,234.56                  |
| Average Amount Spent per Order    | $12.34                     |
+-----------------------------------+----------------------------+
| Cumulative Month with Most Orders | January (12 orders)        |
| Cumulative Month with Most Spent  | January ($123.45)          |
+-----------------------------------+----------------------------+
| Calendar Month with Most Orders   | January 2014 (12 orders)   |
| Calendar Month with Most Spent    | January 2011 ($1,234.56)   |
+-----------------------------------+----------------------------+
```

To update your database, just run `rake orders:fetch` again. By default the task will only update orders that are more than 18 hours old.

## Advanced Usage

The following Rake tasks are available:

| Task Name | Description |
| ------------- | ----------- |
| `rake stats` | Display some interesting stats about your order history.
| `rake orders:fetch` | Log in to Amazon.com and fetch all orders in your history.
| `rake config:generate` | Generate a `config/account.yml` file with your Amazon.com credentials.
| `rake db:reset` | Wipe all local order data.
| `rake db:migrate` | Ensure the DB schema is up-to-date.
| `rake console` | Open an interactive console with the environment loaded (helpful if you want run your own queries or poke around your data).

## Contributing

This project may not capture every order type and probably doesn't work on international Amazon sites.

If you spot a bug, feel free to send me a pull request; currently there are no tests, sorry.

There are a whole bunch of things I'd like to do with this, but I don't have much time presently, so who knows how this project will shape up.

## Authors

[Several people](https://github.com/chrisb/amazon-orders/graphs/contributors) have contributed to this project.

## License

[MIT License](https://github.com/chrisb/amazon-orders/blob/master/LICENSE). Copyright 2015 Chris Bielinski.
