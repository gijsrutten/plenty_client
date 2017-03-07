module PlentyClient
  module Accounting
    extend PlentyClient::Endpoint
    extend PlentyClient::Request

    LIST_VAT_OF_LOCATION    = '/vat/locations/{locationId}'.freeze
    LIST_VAT_OF_COUNTRY     = '/vat/locations/{locationId}/countries/{countryId}'.freeze
    LIST_VAT_CONFIGURATIONS = '/vat'.freeze
    LIST_VAT_STANDARD       = '/vat/standard'.freeze

    class << self
      def list(headers = {}, &block)
        get(build_endpoint(LIST_VAT_CONFIGURATIONS), headers, &block)
      end

      def list_for_country(location_id, country_id, headers = {}, &block)
        get(build_endpoint(LIST_VAT_OF_COUNTRY,
                           location: location_id,
                           country: country_id), headers, &block)
      end

      def list_for_location(location_id, headers = {}, &block)
        get(build_endpoint(LIST_VAT_OF_LOCATION,
                           location: location_id), headers, &block)
      end

      def standard(headers = {}, &block)
        get(build_endpoint(LIST_VAT_STANDARD), headers, &block)
      end
    end
  end
end
