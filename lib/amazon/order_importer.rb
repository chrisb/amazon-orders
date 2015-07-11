module Amazon
  class OrderImporter
    @@css_paths = YAML.load_file('./config/css_paths.yml')['order']
    class << self
      def import(node)
        attrs = {}

        @@css_paths.reject { |k,v| !v }.each_pair do |k,p|
          attrs[k.to_sym] = node.css(p)[0].content.strip
        end

        attrs[:amount_paid] = currency_to_number(attrs[:amount_paid])
        order_id = attrs.delete(:order_id)
        order = Amazon::Order.find_or_initialize_by(order_id: order_id)
        order.update_attributes(attrs)

        node.css('.shipment').count.times { order.shipments.build } if order.shipments.empty?
        node.css('.shipment').each_with_index do |shipment_node, i|
          status_node = shipment_node.css('div > div.a-row.shipment-top-row > div:nth-child(1) > div:nth-child(1) > span.a-size-medium.a-text-bold').first
          order.shipments[i].shipment_status = status_node.content.strip rescue 'Uknown'
        end

        begin
          order.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
          puts "Unable to save order: #{order.inspect}"
        end

        order
      end
      def currency_to_number(currency)
        currency.to_s.gsub(/[$,]/,'').to_f
      end
    end
  end
end
