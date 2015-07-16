module Amazon
  class OrderImporter
    EXPIRATION_THRESHOLD = 18.hours

    @@css_paths = YAML.load_file('./config/css_paths.yml').with_indifferent_access

    class << self
      def order_id_from_node(node)
        node.css(@@css_paths['order_id']).first.content.strip
      end

      def shipment_from_feedback_link(shipment_node)
        link = shipment_node.css('a').find { |l| l['href'].include? 'od_aui_pack_feedback' }
        return nil unless link

        shipment_id = CGI.parse(link['href'].split('?').last)['specificShipmentId'].first
        shipment    = Amazon::Shipment.find_or_create_by(shipment_id: shipment_id)
        shipment.update_attributes delivered: true
        shipment
      end

      def ad_hoc_shipment(order, shipment_index)
        fake_id  = "ORDER-#{order.order_id}-SHIPMENT-#{shipment_index}"
        shipment = Amazon::Shipment.find_or_create_by shipment_id: fake_id
        shipment.update_attributes delivered: true
        shipment
      end

      def shipment_from_tracking_page(shipment_id, tracking_page)
        shipment = Amazon::Shipment.find_or_initialize_by(shipment_id: shipment_id)
        tracking_number_string   = tracking_page.search(@@css_paths['tracking_number']).first.content
        carrier, tracking_number = tracking_number_string.split(',').map { |str| str.split(':').last }.map(&:strip)
        shipment.update_attributes carrier: carrier, tracking_number: tracking_number
        shipment
      end

      def parse_link_for_shipment_id
        CGI.parse(link['href'].split('?').last)['shipmentId'].first
      end

      def shipment_id_from_node(shipment_node)
        link = shipment_node.css('a').find { |l| l['href'].include?('ship-track') }
        return nil unless link

        tracking_page = agent.get(link['href'])

        return nil if tracking_page.body.match(/No tracking details/)

        shipment_from_tracking_page parse_link_for_shipment_id(link), tracking_page
      end

      def parse_shipments_for_order(agent, order, shipment_nodes)
        shipment_nodes.each_with_index do |shipment_node, shipment_index|
          status_node     = shipment_node.css(@@css_paths['status_node']).first
          shipment_status = status_node.content.strip rescue 'Uknown'
          sub_status      = shipment_node.search(@@css_paths['sub_status']).first
          shipment_status = "#{shipment_status}: #{sub_status}" if sub_status
          shipment        = nil

          shipment_node.css('a').each do |link| # find the 'track package' link if possible
            next unless link['href'].include?('ship-track')

            shipment_id   = CGI.parse(link['href'].split('?').last)['shipmentId'].first
            tracking_page = agent.get(link['href'])

            next if tracking_page.body.match(/No tracking details/)

            shipment = shipment_from_tracking_page(shipment_id, tracking_page)
            break
          end

          shipment = shipment_from_feedback_link shipment_node unless shipment # no package tracking link, find shipmentId from feedback link
          shipment = ad_hoc_shipment order, shipment_index unless shipment
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

      def should_skip_order?(order)
        return false if order.new_record? || order.shipments.empty?
        order.updated_at < Time.now + Amazon::OrderImporter::EXPIRATION_THRESHOLD
      end

      def will_skip_order?(order)
        order.skipped = true
        order
      end

      def formatted_line_item_name(name)
        name.gsub('(', '').gsub(')', '').parameterize.gsub('-', '_').to_sym
      end

      def parse_line_items_for_order(order, line_item_nodes)
        order.line_items = line_item_nodes.each_with_object({}) do |line_item_node, hsh|
          next unless line_item_node.css('div > span').size == 2
          name, amount = line_item_node.css('div > span').map(&:content).map(&:strip)
          hsh[formatted_line_item_name name] = currency_to_number(amount)
        end
      end

      def parse_date_for_order(order, node)
        order.date = Date.parse(node.css(@@css_paths['date']).first.content)
        order.save!
      end

      def import(node, agent)
        order = Amazon::Order.find_or_initialize_by(order_id: order_id_from_node(node))

        if should_skip_order?(order)
          order.skipped = true
          return order
        end

        parse_date_for_order order, node

        url = "https://www.amazon.com/gp/your-account/order-details?orderID=#{order.order_id}"
        order_details_page = agent.get(url)

        parse_line_items_for_order order, order_details_page.search(@@css_paths['order_line_item'])
        parse_shipments_for_order agent, order, order_details_page.search(@@css_paths['shipment_node'])
      end

      def handle_error_saving_order(exception, order)
        puts "Unable to save order: #{order.inspect}"
        ap order
        puts 'Shipments:'
        ap order.shipments
        fail exception
      end

      def currency_to_number(currency)
        currency.to_s.gsub(/[$,]/, '').to_f
      end
    end
  end
end
