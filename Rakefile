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

namespace :config do
  desc 'generate a config/account.yml file with your Amazon.com credentials'
  task generate: :dependencies do
    puts "\nNOTE: The credentials you enter\nhere are stored in #{'PLAIN TEXT'.red}.\n\n"
    puts "The credentials will be stored in:\n#{File.expand_path('./config/account.yml').to_s.red}\n\n"

    email = ask 'Amazon.com Account Email: '
    password = ask('Amazon.com Account Password (hidden): ') { |q| q.echo = '*' }

    # confirmation; may or may not want ...
    password_confirm = ask('Confirm Amazon.com Account Password (hidden): ') { |q| q.echo = '*' }
    password = nil unless password == password_confirm

    puts "\n"

    if password.blank? || email.blank?
      puts "No luck with that; please try again.\n\n"
      next
    end

    File.open('./config/account.yml', 'w') { |f| f.puts({ email: email, password: password }.to_yaml) }
    puts "Wrote values to #{File.expand_path('./config/account.yml').to_s}\n\n"
  end
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
          t.float :amount_total, default: 0, null: false
          t.float :amount_tax, default: 0, null: false
          t.boolean :gift, default: false, null: false
          t.boolean :completed, default: false, null: false
          t.timestamps null: false
        end
        create_table :shipments, force: true, id: false do |t|
          t.string :shipment_id, null: false, index: true, unique: true
          t.string :ship_to
          t.string :shipment_status
          t.boolean :delivered, default: false, null: false, index: true
          t.timestamps null: false
        end
        create_table :shipment_orders, force: true, id: false do |t|
          t.string :shipment_id, null: false, index: true
          t.string :order_id, null: false, index: true
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
    begin
      puts "Loading account settings ..."
      account = YAML.load_file('./config/account.yml').with_indifferent_access
    rescue Errno::ENOENT
      puts "\nHmm... no settings found.\n".red
      puts "Let's create a configuration file!".green
      Rake::Task['config:generate'].execute
      retry
    end

    agent   = Mechanize.new { |a| a.user_agent_alias = 'Mac Safari' }
    puts "Loading #{'Amazon.com'.yellow}..."
    agent.get('https://www.amazon.com/') do |page|
      puts "Loading the login page.."
      login_page = agent.click(page.link_with(href: %r{ap/signin}))
      puts "Filling out the form and logging in..."
      begin
        post_login_page = login_page.form_with(action: %r{ap/signin}) do |f|
          account.each_pair { |k,v| f.send "#{k}=", v }
        end.click_button
        orders_page = agent.click(post_login_page.link_with(text: 'Your Orders'))
      rescue NoMethodError
        puts "\nLogging in to Amazon.com failed.\n".red
        puts "Try running #{'rake config:generate'.yellow} and updating your credentials."
        next
      end

      puts "Logged in successfully -- loading up your orders!\n"

      begin
        Amazon::Order.count
      rescue ActiveRecord::StatementInvalid
        Rake::Task['db:migrate'].execute
      end

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
              order = Amazon::OrderImporter.import(node, agent)
              action = order.skipped? ? 'skipped' : nil
              ( action = order.new_order? ? 'imported' : 'updated' ) if action.nil?
              puts "    #{action.titleize.yellow} Order ##{order.order_id.green} (#{order.reload.shipments.count} shipments)"
            end
            begin
              last_pagination_element = orders_page.search('ul.a-pagination li.a-last')[0]
              link = last_pagination_element.css('a')[0]
            rescue NoMethodError
              throw :no_more_orders
            end
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
