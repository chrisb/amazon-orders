module Amazon
  class OrderImporter
    EXPIRATION_THRESHOLD = 18.hours

    @@css_paths = YAML.load_file('./config/css_paths.yml').with_indifferent_access

    class << self
      def order_id_from_node(node)
        node.css(@@css_paths['order_id']).first.content.strip
      end

      def import(node, agent)
        order = Amazon::Order.find_or_initialize_by(order_id: order_id_from_node(node))

        if !order.new_record? && order.updated_at < Time.now + Amazon::OrderImporter::EXPIRATION_THRESHOLD && !order.shipments.empty?
          order.skipped = true
          return order
        end

        url = "https://www.amazon.com/gp/your-account/order-details?orderID=#{order.order_id}"
        order_details_page = agent.get(url)

        line_item_nodes  = order_details_page.search(@@css_paths['order_line_item'])
        order.line_items = line_item_nodes.each_with_object({}) do |line_item_node, hsh|
          next unless line_item_node.css('div > span').size == 2
          name, amount     = line_item_node.css('div > span').map(&:content).map(&:strip)
          name             = name.gsub('(', '').gsub(')', '').parameterize.gsub('-', '_')
          hsh[name.to_sym] = currency_to_number(amount)
        end

        order.date = Date.parse(node.css(@@css_paths['date']).first.content)
        order.save!

        shipment_nodes = order_details_page.search(@@css_paths['shipment_node'])
        shipment_nodes.each_with_index do |shipment_node, shipment_index|
          status_node     = shipment_node.css(@@css_paths['status_node']).first
          shipment_status = status_node.content.strip rescue 'Uknown'
          sub_status      = shipment_node.search(@@css_paths['sub_status']).first
          shipment_status = "#{shipment_status}: #{sub_status}" if sub_status
          shipment        = nil

          shipment_node.css('a').each do |link| # find the 'track package' link if possible
            next unless link['href'].include?('ship-track')

            shipment_id              = CGI.parse(link['href'].split('?').last)['shipmentId'].first
            tracking_page            = agent.get(link['href'])

            unless tracking_page.body.match(/No tracking details/)
              shipment = Amazon::Shipment.find_or_initialize_by(shipment_id: shipment_id)
              tracking_number_string   = tracking_page.search(@@css_paths['tracking_number']).first.content
              carrier, tracking_number = tracking_number_string.split(',').map { |str| str.split(':').last }.map(&:strip)
              shipment.update_attributes carrier: carrier, tracking_number: tracking_number
            end

            break
          end

          if shipment.nil? # no package tracking link, find shipmentId from feedback link
            shipment_node.css('a').each do |link|
              next unless link['href'].include?('od_aui_pack_feedback')
              shipment_id = CGI.parse(link['href'].split('?').last)['specificShipmentId'].first
              shipment    = Amazon::Shipment.find_or_create_by(shipment_id: shipment_id)
              shipment.update_attributes delivered: true
              break
            end
          end

          if shipment.nil? # this must be a really old order
            fake_id  = "ORDER-#{order.order_id}-SHIPMENT-#{shipment_index}"
            shipment = Amazon::Shipment.find_or_create_by shipment_id: fake_id
            shipment.update_attributes delivered: true
          end

          shipment.update_attributes shipment_status: shipment_status
          shipment.save!

          order.shipments << shipment
        end

        begin
          order.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved  => e
          handle_error_saving_order e, order
        end

        order
      end

      def handle_error_saving_order(exception, order)
        puts "Unable to save order: #{order.inspect}"
        ap order
        puts 'Shipments:'
        ap order.shipments
        raise exception
      end

      def currency_to_number(currency)
        currency.to_s.gsub(/[$,]/, '').to_f
      end
    end
  end
end
