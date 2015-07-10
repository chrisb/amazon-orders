desc 'load all required gems and dependencies'
task :dependencies do
  require 'rubygems'
  require 'yaml'
  require 'bundler'

  Bundler.require
end

task establish_connection: :dependencies do
  ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: 'orders.sqlite3'
end

desc 'load the environment'
task environment: :dependencies do
  Rake::Task['establish_connection'].execute
  require './lib/amazon/order'
  require './lib/amazon/order_importer'
end

namespace :db do
  desc 'ensure the DB schema is up-to-date'
  task migrate: :establish_connection do
    CURRENT_SCHEMA_VERSION = 2
    if ActiveRecord::Migrator.current_version != CURRENT_SCHEMA_VERSION
      ActiveRecord::Schema.define(version: CURRENT_SCHEMA_VERSION) do
        create_table :orders, id: false, force: true do |t|
          t.string :order_id, null: false, index: true, unique: true
          t.date :date, null: false
          t.string :ship_to
          t.float :total, null: false
          t.string :shipment_status
          t.boolean :delivered, default: false, null: false
        end
      end
    end
  end
end

namespace :orders do

  desc 'import orders from test/data'
  task import: :environment do
    page = 0
    while File.exists?("./test/data/orders-#{page}.html")
      Nokogiri::HTML(File.open("./test/data/orders-#{page}.html"))
        .css('#ordersContainer > .order')
        .each { |node| Amazon::OrderImporter.import(node) }
      page += 1
    end
  end

  desc 'log in to amazon and fetch all orders'
  task fetch: :environment do
    account = YAML.load_file('./config/account.yml').with_indifferent_access
    agent   = Mechanize.new { |a| a.user_agent_alias = 'Mac Safari' }
    agent.get('https://www.amazon.com/') do |page|
      login_page = agent.click(page.link_with(href: %r{ap/signin}))
      post_login_page = login_page.form_with(action: %r{ap/signin}) do |f|
        account.each_pair do |key, value|
          f.send "#{key}=", value
        end
      end.click_button
      page        = 0
      orders_page = agent.click(post_login_page.link_with(text: 'Your Orders'))
      catch :no_more_orders do
        loop do
          puts "Parsing orders page #{(page+1).to_s.red}"
          orders_page.search('#ordersContainer > .order').each do |node|
            order = Amazon::OrderImporter.import(node)
            puts "  Imported (or updated) Order ##{order.order_id.green}"
          end
          next_page_element = orders_page.search('ul.a-pagination li.a-last')[0]
          link = next_page_element.css('a')[0]
          throw :no_more_orders unless link
          orders_page = agent.click(link)
          page += 1
        end
      end
      puts "\nYippee! All done."
    end
  end
end
