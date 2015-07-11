desc 'load all required gems and dependencies'
task :dependencies do
  require 'rubygems'
  require 'yaml'
  require 'bundler'
  Bundler.require
end

task establish_connection: :dependencies do
  ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: 'db/orders.sqlite3'
end

desc 'load the environment'
task environment: :dependencies do
  Rake::Task['establish_connection'].execute
  require './lib/amazon/order'
  require './lib/amazon/shipment'
  require './lib/amazon/order_importer'
end

desc 'load an interactive console'
task console: :environment do
  require 'pry'
  ARGV.clear
  Pry.start
end

namespace :db do
  desc 'wipe all local order data'
  task reset: :establish_connection do
    File.unlink './db/orders.sqlite3' rescue Errno::ENOENT
    Rake::Task['db:migrate'].execute
  end

  desc 'ensure the DB schema is up-to-date'
  task migrate: :establish_connection do
    CURRENT_SCHEMA_VERSION = 2
    if ActiveRecord::Migrator.current_version != CURRENT_SCHEMA_VERSION
      ActiveRecord::Schema.define(version: CURRENT_SCHEMA_VERSION) do
        create_table :orders, id: false, force: true do |t|
          t.string :order_id, null: false, index: true, unique: true
          t.date :date, null: false
          t.float :amount_paid, default: 0, null: false
          t.boolean :gift, default: false, null: false
          t.boolean :completed, default: false, null: false
          t.timestamps null: false
        end
        create_table :shipments, force: true do |t|
          t.string :order_id, null: false, index: true
          t.string :ship_to
          t.string :shipment_status
          t.boolean :delivered, default: false, null: false, index: true
          t.timestamps null: false
        end
        add_index :shipments, [:order_id, :delivered]
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
    puts "Loading account settings ..."
    account = YAML.load_file('./config/account.yml').with_indifferent_access
    agent   = Mechanize.new { |a| a.user_agent_alias = 'Mac Safari' }
    puts "Loading #{'Amazon.com'.yellow}..."
    agent.get('https://www.amazon.com/') do |page|
      puts "Loading the login page.."
      login_page = agent.click(page.link_with(href: %r{ap/signin}))
      puts "Filling out the form and logging in..."
      post_login_page = login_page.form_with(action: %r{ap/signin}) do |f|
        account.each_pair { |k,v| f.send "#{k}=", v }
      end.click_button
      puts "Logged in successfully -- loading up your orders!\n"
      orders_page = agent.click(post_login_page.link_with(text: 'Your Orders'))
      years = orders_page.search('form#timePeriodForm select[name=orderFilter] option[value^="year-"]').map do |option_tag|
        option_tag.content.strip.to_i
      end

      years.each do |year|
        puts "Looking up orders from #{year.to_s.blue}..."
        orders_page = orders_page.form_with(id: 'timePeriodForm') do |f|
          f.orderFilter = "year-#{year}"
        end.submit
        page = 0
        catch :no_more_orders do
          loop do
            puts "  Parsing orders from #{year.to_s.blue} (page #{(page+1).to_s.red})"
            orders_page.search('#ordersContainer > .order').each do |node|
              order = Amazon::OrderImporter.import(node)
              puts "    Imported (or updated) Order ##{order.order_id.green} (#{order.reload.shipments.count} shipments)"
            end
            link = orders_page.search('ul.a-pagination li.a-last')[0].css('a')[0]
            throw :no_more_orders unless link
            orders_page = agent.click(link)
            page += 1
          end
        end

      end
      
      puts "\nYippee! All done."
    end
  end
end
