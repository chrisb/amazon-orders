module Amazon
  class Order < ActiveRecord::Base
    self.primary_key = :order_id

    attr_accessor :skipped
    attr_accessor :new_order

    has_many :shipment_orders, class_name: 'Amazon::ShipmentOrder'
    has_many :shipments, through: :shipment_orders, class_name: 'Amazon::Shipment'

    with_options numericality: { greater_than_or_equal_to: 0 } do |m|
      m.validates :grand_total
      m.validates :items_subtotal
      m.validates :estimated_tax_to_be_collected
    end

    before_save :set_completion
    before_save :set_new_order, on: :create

    before_validation :set_amounts_from_line_items, on: :create

    serialize :line_items, JSON

    after_initialize :set_default_values

    def set_default_values
      self.skipped    = !new_record?
      self.new_order  = new_record?
      self.line_items = {}
    end

    def skipped? ; @skipped ; end

    def new_order? ; @new_order ; end

    def set_amounts_from_line_items
      line_items.each_pair { |key, amount| self.send "#{key}=", amount if self.respond_to?("#{key}=") }
    end

    def set_new_order
      self.new_order = true
    end

    def set_completion
      self.skipped   = false
      self.completed = shipments.count == shipments.delivered.count
      true
    end
  end
end
